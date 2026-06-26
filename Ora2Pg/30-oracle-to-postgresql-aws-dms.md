# 30. Oracle 19c to PostgreSQL migration with AWS DMS

이 문서는 Oracle 19c 데이터를 AWS의 공식 Oracle -> PostgreSQL 이기종 마이그레이션 스택으로 변환하고,
최종 PostgreSQL 산출물을 온프레미스 또는 다른 클라우드 PostgreSQL로 가져가는 절차를 정리한다.

범위는 AWS만 다룬다.

## 결론

- **RMAN 백업 파일만으로 DMS Schema Conversion/DMS data migration을 직접 수행하지 않는다.**
  AWS DMS는 Oracle redo/metadata/table data를 읽기 위해 source Oracle 데이터베이스에 네트워크로 접속한다.
- RMAN은 복구/스냅샷/롤백용으로는 유용하지만, AWS DMS 입력값은 “백업 파일”이 아니라
  **접속 가능한 Oracle 19c 인스턴스 + DMS 전용 계정 + ARCHIVELOG/supplemental logging**이다.
- 반복 가능한 실무 경로는 다음이 가장 단순하다.
  1. Oracle 19c 원본을 유지하거나 AWS에서 접속 가능한 복제 Oracle 인스턴스를 준비한다.
  2. AWS에 임시 RDS for PostgreSQL 또는 Aurora PostgreSQL target을 만든다.
  3. DMS Schema Conversion으로 schema/code를 평가/변환/적용한다.
  4. AWS DMS replication task 또는 DMS Serverless로 table data를 full-load(+필요 시 CDC)한다.
  5. 검증 후 `pg_dump -Fc`로 PostgreSQL DB를 내려받아 온프레미스/타 클라우드 PostgreSQL에 `pg_restore`한다.

## Oracle 데이터 준비

### 필요한 형태

AWS DMS가 source Oracle에 접속할 수 있어야 한다.

- On-prem Oracle 19c가 AWS VPC에서 접근 가능: VPN, Direct Connect, 방화벽 허용, DNS/route/security group 구성.
- 또는 Oracle 백업을 별도 Oracle 19c 인스턴스에 복구한 뒤 그 인스턴스를 DMS source로 사용.

RMAN 백업을 받는다면 목적은 “DMS 입력”이 아니라 다음이다.

- 마이그레이션 전 복구 지점 확보.
- 운영 DB에 직접 부하를 주기 싫을 때, RMAN으로 복제 Oracle 인스턴스를 만든 뒤 DMS가 그 복제본을 읽게 함.

### Oracle 19c source 설정

full-load만 할 경우에도 DMS 계정과 네트워크 접근이 필요하다. 운영 전환까지 변경분을 따라가려면 CDC가 필요하고,
CDC에는 ARCHIVELOG와 supplemental logging이 필요하다.

```sql
-- ARCHIVELOG 확인
SELECT log_mode FROM v$database;

-- supplemental logging 확인
SELECT supplemental_log_data_min FROM v$database;

-- 필요 시 DB 레벨 최소 supplemental logging
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;

-- PK 기반 CDC를 명확히 하려면 테이블 또는 DB 레벨 PK supplemental logging
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (PRIMARY KEY) COLUMNS;
```

DMS source 계정은 최소 권한으로 별도 생성한다. 실제 권한은 선택한 capture 방식(LogMiner/Binary Reader),
schema 범위, LOB 사용 여부에 따라 보정한다.

```sql
CREATE USER dms_user IDENTIFIED BY "<strong-password>";
GRANT CREATE SESSION TO dms_user;
GRANT SELECT ANY TABLE TO dms_user;
GRANT SELECT ANY TRANSACTION TO dms_user;
GRANT SELECT_CATALOG_ROLE TO dms_user;

-- LogMiner 사용 시
GRANT EXECUTE ON DBMS_LOGMNR TO dms_user;
GRANT SELECT ON V_$LOGMNR_LOGS TO dms_user;
GRANT SELECT ON V_$LOGMNR_CONTENTS TO dms_user;
GRANT LOGMINING TO dms_user;

-- DMS가 PK supplemental logging을 추가하게 할 경우 각 replicated table에 ALTER 권한 필요
-- 또는 DBA가 위 supplemental logging을 사전에 직접 적용한다.
```

## AWS 선행 리소스

필수:

- VPC, subnet group, security group
  - DMS Schema Conversion instance profile과 DMS replication이 Oracle source와 PostgreSQL target에 접근 가능해야 한다.
- S3 bucket
  - DMS Schema Conversion assessment/exported SQL 저장.
  - 필요 시 RDS PostgreSQL query export 또는 snapshot export 저장.
- Secrets Manager secret
  - Oracle source 접속 정보.
  - PostgreSQL target 접속 정보.
- IAM role/policy
  - DMS Schema Conversion이 S3와 Secrets Manager를 읽을 수 있어야 한다.
  - RDS snapshot export를 쓴다면 `export.rds.amazonaws.com`용 role과 KMS key 권한이 별도로 필요하다.
- 임시 target PostgreSQL
  - 권장: RDS for PostgreSQL 또는 Aurora PostgreSQL.
  - 목적은 AWS 내부에서 DMS target으로 받아 변환 결과를 검증하고 dump를 생성하는 것이다.

## IaC/API 가능 여부

가능하다.

- DMS Schema Conversion은 API/CLI로 instance profile, data provider, migration project를 만들 수 있다.
- metadata assessment, conversion, SQL export, target 적용도 CLI/API가 있다.
- DMS data migration은 endpoint, replication config/task, start/stop을 CLI/API로 만들 수 있다.
- 다만 변환 품질 판단과 action item 수정은 사람의 검토가 필요하다. IaC는 “반복 가능한 환경/명령”을 보장하고,
  SQL 수정본은 git에 관리하는 방식이 맞다.

## 핵심 AWS CLI 골격

아래 값은 예시다. 실제 값은 `aws-migration.env` 같은 파일로 분리하고 스크립트가 source 하도록 만든다.

```bash
export AWS_REGION=ap-northeast-2
export PROJECT=oracle19c-to-pg
export S3_BUCKET=my-dms-sc-artifacts
export DMS_SUBNET_GROUP_ID=dms-sc-subnets
export DMS_SECURITY_GROUP_ID=sg-xxxxxxxx
```

### 1. Secrets Manager

```bash
aws secretsmanager create-secret \
  --name "${PROJECT}/oracle-source" \
  --secret-string '{"username":"dms_user","password":"<password>"}'

aws secretsmanager create-secret \
  --name "${PROJECT}/pg-target" \
  --secret-string '{"username":"postgres","password":"<password>"}'
```

### 2. DMS Schema Conversion instance profile

```bash
INSTANCE_PROFILE_ARN="$(
  aws dms create-instance-profile \
    --instance-profile-name "${PROJECT}-sc" \
    --network-type IPV4 \
    --subnet-group-identifier "${DMS_SUBNET_GROUP_ID}" \
    --vpc-security-groups "${DMS_SECURITY_GROUP_ID}" \
    --query 'InstanceProfile.InstanceProfileArn' \
    --output text
)"
```

### 3. Data providers

```bash
ORACLE_DP_ARN="$(
  aws dms create-data-provider \
    --data-provider-name "${PROJECT}-oracle" \
    --engine oracle \
    --settings '{
      "OracleSettings": {
        "ServerName": "oracle.example.internal",
        "Port": 1521,
        "DatabaseName": "ORCLPDB1",
        "SslMode": "none"
      }
    }' \
    --query 'DataProvider.DataProviderArn' \
    --output text
)"

PG_DP_ARN="$(
  aws dms create-data-provider \
    --data-provider-name "${PROJECT}-postgres" \
    --engine postgres \
    --settings '{
      "PostgreSqlSettings": {
        "ServerName": "target.xxxxxx.ap-northeast-2.rds.amazonaws.com",
        "Port": 5432,
        "DatabaseName": "appdb",
        "SslMode": "none"
      }
    }' \
    --query 'DataProvider.DataProviderArn' \
    --output text
)"
```

### 4. Migration project

```bash
MIGRATION_PROJECT_ARN="$(
  aws dms create-migration-project \
    --migration-project-name "${PROJECT}" \
    --instance-profile-identifier "${INSTANCE_PROFILE_ARN}" \
    --source-data-provider-descriptors "{
      \"DataProviderIdentifier\": \"${ORACLE_DP_ARN}\",
      \"SecretsManagerSecretId\": \"arn:aws:secretsmanager:${AWS_REGION}:<account-id>:secret:${PROJECT}/oracle-source-xxxxxx\",
      \"SecretsManagerAccessRoleArn\": \"arn:aws:iam::<account-id>:role/dms-sc-secrets-role\"
    }" \
    --target-data-provider-descriptors "{
      \"DataProviderIdentifier\": \"${PG_DP_ARN}\",
      \"SecretsManagerSecretId\": \"arn:aws:secretsmanager:${AWS_REGION}:<account-id>:secret:${PROJECT}/pg-target-xxxxxx\",
      \"SecretsManagerAccessRoleArn\": \"arn:aws:iam::<account-id>:role/dms-sc-secrets-role\"
    }" \
    --schema-conversion-application-attributes "{
      \"S3BucketPath\": \"s3://${S3_BUCKET}/${PROJECT}\",
      \"S3BucketRoleArn\": \"arn:aws:iam::<account-id>:role/dms-sc-s3-role\"
    }" \
    --query 'MigrationProject.MigrationProjectArn' \
    --output text
)"
```

### 5. Assessment / conversion / export / apply

선택 규칙은 처음에는 schema 단위로 작게 시작한다.
`server-name`/`schema-name` 표기는 DMS Schema Conversion metadata tree에서 보이는 이름에 맞춰 조정한다.

```bash
cat > selection-rules.json <<'JSON'
{
  "rules": [
    {
      "rule-type": "selection",
      "rule-id": "1",
      "rule-name": "include-app-schema",
      "object-locator": {
        "schema-name": "APP_SCHEMA",
        "table-name": "%"
      },
      "rule-action": "explicit"
    }
  ]
}
JSON

aws dms start-metadata-model-import \
  --migration-project-identifier "${MIGRATION_PROJECT_ARN}" \
  --origin SOURCE \
  --refresh \
  --selection-rules file://selection-rules.json

aws dms start-metadata-model-assessment \
  --migration-project-identifier "${MIGRATION_PROJECT_ARN}" \
  --selection-rules file://selection-rules.json

aws dms start-metadata-model-conversion \
  --migration-project-identifier "${MIGRATION_PROJECT_ARN}" \
  --selection-rules file://selection-rules.json

aws dms start-metadata-model-export-as-script \
  --migration-project-identifier "${MIGRATION_PROJECT_ARN}" \
  --origin TARGET \
  --selection-rules file://selection-rules.json

aws dms start-metadata-model-export-to-target \
  --migration-project-identifier "${MIGRATION_PROJECT_ARN}" \
  --selection-rules file://selection-rules.json \
  --overwrite-extension-pack
```

변환 SQL은 S3에서 내려받아 git에 보관하고, 사람이 action item을 수정한 SQL을 별도 파일로 관리한다.

## Data migration

Schema가 target PostgreSQL에 적용된 뒤 table data를 적재한다.

단순 검증/1회 전환이면 `full-load`로 충분하다. 운영 전환 시점까지 Oracle 변경분을 따라가야 하면
`full-load-and-cdc`를 쓴다.

### DMS endpoints

```bash
ORACLE_EP_ARN="$(
  aws dms create-endpoint \
    --endpoint-identifier "${PROJECT}-oracle-src" \
    --endpoint-type source \
    --engine-name oracle \
    --server-name oracle.example.internal \
    --port 1521 \
    --database-name ORCLPDB1 \
    --username dms_user \
    --password '<password>' \
    --query 'Endpoint.EndpointArn' \
    --output text
)"

PG_EP_ARN="$(
  aws dms create-endpoint \
    --endpoint-identifier "${PROJECT}-pg-tgt" \
    --endpoint-type target \
    --engine-name postgres \
    --server-name target.xxxxxx.ap-northeast-2.rds.amazonaws.com \
    --port 5432 \
    --database-name appdb \
    --username postgres \
    --password '<password>' \
    --query 'Endpoint.EndpointArn' \
    --output text
)"
```

### DMS Serverless replication config

```bash
cat > table-mappings.json <<'JSON'
{
  "rules": [
    {
      "rule-type": "selection",
      "rule-id": "1",
      "rule-name": "include-app-schema",
      "object-locator": {
        "schema-name": "APP_SCHEMA",
        "table-name": "%"
      },
      "rule-action": "include"
    }
  ]
}
JSON

REPL_CONFIG_ARN="$(
  aws dms create-replication-config \
    --replication-config-identifier "${PROJECT}-full-load" \
    --source-endpoint-arn "${ORACLE_EP_ARN}" \
    --target-endpoint-arn "${PG_EP_ARN}" \
    --replication-type full-load \
    --compute-config "{
      \"MinCapacityUnits\": 1,
      \"MaxCapacityUnits\": 4,
      \"MultiAZ\": false,
      \"ReplicationSubnetGroupId\": \"${DMS_SUBNET_GROUP_ID}\",
      \"VpcSecurityGroupIds\": [\"${DMS_SECURITY_GROUP_ID}\"]
    }" \
    --table-mappings file://table-mappings.json \
    --query 'ReplicationConfig.ReplicationConfigArn' \
    --output text
)"

aws dms start-replication \
  --replication-config-arn "${REPL_CONFIG_ARN}" \
  --start-replication-type start-replication
```

대량/운영 전환이면 `full-load-and-cdc`로 바꾸고 Oracle ARCHIVELOG/supplemental logging과 archive retention을
반드시 확인한다.

## PostgreSQL 결과물 내려받기

AWS target PostgreSQL이 최종 검증본이면 `pg_dump`가 가장 이식성이 좋다.

```bash
pg_dump \
  -h target.xxxxxx.ap-northeast-2.rds.amazonaws.com \
  -p 5432 \
  -U postgres \
  -d appdb \
  -Fc -b -v \
  -f appdb-from-oracle.pgcustom

pg_dumpall \
  -h target.xxxxxx.ap-northeast-2.rds.amazonaws.com \
  -U postgres \
  --no-role-passwords \
  -g \
  -f appdb-global-roles.sql
```

온프레미스 또는 다른 클라우드 PostgreSQL에 복원:

```bash
createdb -h target-pg.example.internal -U postgres appdb
psql -h target-pg.example.internal -U postgres -f appdb-global-roles.sql
pg_restore -h target-pg.example.internal -U postgres -d appdb -j 4 -v appdb-from-oracle.pgcustom
```

RDS for PostgreSQL의 `aws_s3` extension으로 query 결과를 S3에 export할 수도 있지만, 전체 DB 이식 목적이면
`pg_dump -Fc`가 더 직접적이고 단순하다.

## 최소 검증 체크리스트

- Oracle source:
  - DMS에서 TCP 1521 접근 가능.
  - DMS 계정 로그인 가능.
  - CDC를 쓰면 ARCHIVELOG, supplemental logging, archive retention 확인.
- Schema conversion:
  - assessment report 저장.
  - action item 목록 검토.
  - 변환 SQL을 git에 저장.
  - extension pack 적용 여부 기록.
- Data migration:
  - full-load table statistics 확인.
  - row count 비교.
  - PK/UK/FK/index/sequence 재검증.
  - 대표 업무 쿼리 검증.
- Export:
  - `pg_dump -Fc` 생성.
  - 별도 PostgreSQL에 `pg_restore` 리허설.

## 참고 AWS 문서

- DMS Schema Conversion 개요: https://docs.aws.amazon.com/dms/latest/userguide/CHAP_SchemaConversion.html
- DMS supported sources/targets: https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Introduction.Sources.html / https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Introduction.Targets.html
- Oracle source for AWS DMS: https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Source.Oracle.html
- DMS Schema Conversion prerequisites/IAM: https://docs.aws.amazon.com/dms/latest/userguide/set-up.html
- DMS Schema Conversion data providers/projects: https://docs.aws.amazon.com/dms/latest/userguide/migration-projects.html
- DMS Schema Conversion CLI workflow: https://aws.amazon.com/blogs/database/assess-and-migrate-your-database-using-aws-dms-schema-conversion-cli/
- DMS Serverless replication config CLI: https://docs.aws.amazon.com/cli/latest/reference/dms/create-replication-config.html
- PostgreSQL `pg_dump`/`pg_restore`: https://docs.aws.amazon.com/dms/latest/sbs/chap-manageddatabases.postgresql-rds-postgresql-full-load-pd_dump.html
