# AWS DMS 기반 Oracle → PostgreSQL 마이그레이션 (wrtp)

온프레미스 Oracle 19c(`ORCLPDB1.SAMPLE`)를 **AWS DMS Schema Conversion + AWS DMS**로 PostgreSQL로
변환·적재한 뒤, 그 DB를 **온프레미스로 내려받아** 운영하고, **AWS 리소스는 전부 정리**한다.
이 문서 하나로 전 과정을 재현할 수 있게 유지한다.

- IaC: **CloudFormation** (스택 단위로 "내가 만든 것만" 삭제) · 리전 **ap-northeast-2**
- 방식: **Full Load**(기본) 또는 **Full Load + CDC**(`MIGRATION_TYPE`) · 타깃: **임시 RDS for PostgreSQL 16**
- Oracle 측 준비/접속값: [AWS_DMS_SETUP.md](AWS_DMS_SETUP.md) (계정 `C##DMS`/`C##DMS_SC`, 서비스 `ORCLPDB1`)

## 안전 규칙 (반드시 지킴)

- 모든 리소스에 태그 `Project=wrtp` + 이름 접두 `wrtp-`. (wrtp = aws oracle → postgresql)
- **이번 코드로 만든 리소스만** 삭제. 태그/스택에 없는 것은 절대 미삭제.
- **삭제는 dry-run이 기본** (`9100` 인자 없이 실행 = 미리보기). 실제 삭제는 `--apply` + 확인.
- RDS(데이터 보유)와 계정 공유 역할(`dms-vpc-role` 등)은 삭제 전 개별 확인. 우리가 만들지 않은 공유 역할은 미삭제.
- 비밀번호는 **Secrets Manager**에만. config.env·템플릿·git에 평문 저장 금지.

## 사전 준비

1. `cp config.env.example config.env` 후 채우기: `ORACLE_PUBLIC_IP`, `ONPREM_CIDR`(이 서버 공인 IP/32) 등.
2. AWS 자격증명: `0100`이 안내하는 IAM 정책([iam/wrtp-migration-policy.json](iam/wrtp-migration-policy.json))을
   IAM 사용자/역할에 부착하고 `aws configure`.

## 실행 순서 (한 번에 한 단계, 성공 후 다음)

| 단계 | 스크립트 | 내용 |
|---|---|---|
| 0100 | `bin/0100_install-tools-and-check-aws-permissions` | aws cli 설치 + 권한 게이트 |
| 0120 | `bin/0120_grant-oracle-cdc-privileges` | (CDC) C##DMS Binary Reader 권한 부여 — full-load면 자동 스킵 |
| 0140 | `bin/0140_enable-oracle-cdc-redo` | (CDC) ARCHIVELOG(재시작)+보충로깅; dry-run 기본, `--apply` |
| 0150 | `bin/0150_ensure-shared-dms-service-roles` | dms-vpc-role/cloudwatch-logs-role 확인·생성(공유) |
| 0200 | `bin/0200_create-network` | VPC/서브넷/IGW/SG |
| 0300 | `bin/0300_create-foundation-s3-secrets-iam` | S3(SSE-S3)/Secrets/IAM 역할 |
| 0400 | `bin/0400_set-connection-secrets` | Oracle·PG 자격증명 주입(미저장) |
| 0500 | `bin/0500_create-target-postgresql-rds` | 임시 RDS PG16 |
| 0600 | `bin/0600_create-schema-conversion-project` | DMS Schema Conversion |
| 0700 | `bin/0700_run-schema-assessment-report` | 평가 리포트 |
| 0800 | `bin/0800_convert-and-apply-schema-to-target` | 스키마 변환·적용 |
| 0850 | `bin/0850_fix-postgresql-schema-after-dms-conversion` | DMS 변환 후 PostgreSQL 스키마 보정 |
| 0900 | `bin/0900_create-data-migration-task` | DMS full-load 태스크 |
| 1000 | `bin/1000_test-endpoint-connections` | 엔드포인트 연결 테스트 |
| 1100 | `bin/1100_run-full-load-and-validate` | full-load + 검증 (CDC면 이후 ongoing replication) |
| 1150 | `bin/1150_monitor-cdc-replication` | (CDC) 태스크 상태·변경건수·지연 모니터(읽기) |
| 1160 | `bin/1160_validate-cdc-change` | (CDC) Oracle 변경이 RDS로 전파되는지 검증 |
| 1180 | `bin/1180_stop-cdc-for-cutover` | (CDC) 소스 정지 후 컷오버·시퀀스 보정 |
| 1200 | `bin/1200_download-postgresql-dump` | pg_dump 다운로드 |
| 1300 | `bin/1300_restore-dump-to-onprem-postgresql` | 온프레미스 복원(선택) |
| 1400 | `bin/1400_compare-conversions` | Ora2Pg 결과와 AWS DMS 복원 결과 간 단순 객체 비교 |
| 1450 | `bin/1450_compare-oracle-source-to-postgresql-conversions` | Oracle 원본 기준 Ora2Pg/AWS DMS 3자 검증 |
| 9000 | `bin/9000_list-wrtp-resources` | wrtp 리소스 인벤토리(읽기) |
| 9100 | `bin/9100_teardown-wrtp-resources` | AWS 정리(dry-run 기본; DMS 로그그룹 포함) |
| 9200 | `bin/9200_revert-oracle-cdc-prerequisites` | (CDC) Oracle 변경 되돌리기 — 권한·보충로깅·디렉터리; `--disable-archivelog`=ARCHIVELOG 환원(재시작) |

생성되는 리소스 규칙·목록은 [CREATED_RESOURCES.md](CREATED_RESOURCES.md) 참고.

## 비용 주의

복제 인스턴스·RDS·Schema Conversion 인스턴스는 **시간당 과금**. 다운로드(1200) 직후 `9100`으로 정리한다.
**CDC 모드(`full-load-and-cdc`)** 에서는 복제 인스턴스+RDS 가 컷오버(`1180`)까지 계속 과금되므로,
`1180`→`1200` 완료 후에만 `9100`으로 정리한다.

## 로컬 산출물 주의

`output/s3/`는 현재 S3 버킷의 mirror로 유지한다. `0700`/`0800`은 `aws s3 sync --delete`를 사용해
이전 실행의 assessment/converted 파일이 현재 실행 결과와 섞이지 않게 한다.

## DMS 변환 후 보정

`0800`의 DMS 작업 상태가 `SUCCESS`여도 apply-result CSV에 객체별 오류가 남을 수 있다. 현재 SAMPLE 스키마에서는
`orders.tax_amount` 생성 컬럼의 `round(double precision, integer)` 오류 때문에 `orders`와 의존 객체가 연쇄 실패한다.
`0850`은 이 보정을 SQL 파일로 재현 가능하게 적용한 뒤, data load에 필요한 테이블·뷰·제약조건 존재를 검증한다.
`fx_ord_trunc_date`는 DMS가 만든 `aws_oracle_ext.TRUNC(order_date)` 표현식이 immutable index 조건을 만족하지 않아
같은 이름의 `order_date` BTREE 인덱스로 단순화한다.
또한 DMS full-load는 PostgreSQL generated column에 값을 넣을 수 없으므로 `orders.tax_amount`와
`order_items.line_total`은 일반 컬럼으로 받는다. Oracle NUMBER가 소수 표기로 내려오는 `audit_log.audit_id`는
identity 속성을 제거하고 `numeric`으로 받는다.

## Oracle 원본 기준 변환 검증

`1450`은 Oracle 원본을 기준으로 Ora2Pg 결과 DB와 AWS DMS 복원 DB를 비교한다. 특정 테이블명이나 행 수를
하드코딩하지 않고 Oracle/PostgreSQL catalog에서 테이블·뷰·MV·시퀀스·루틴·트리거·인덱스를 수집한다.
일반 테이블은 전체 목록을 자동으로 세어 행 수를 비교하고, Oracle materialized view는 PostgreSQL에서
materialized view/table/missing 중 어떤 형태로 변환됐는지 별도로 표시한다.

View/MV는 `SELECT 1 FROM ... LIMIT 1` 방식으로 실행 가능성을 확인한다. 루틴은 인자를 무작위 추론하지 않고
`sql/1450_postgresql-routine-smoke-tests.sql`에 유지보수되는 smoke test만 자동 실행한다. 데이터 변경 가능성이
있는 `CALL`은 트랜잭션 안에서 실행 후 `ROLLBACK`한다.

결과는 `output/ORACLE_SOURCE_CONVERSION_COMPARISON.md`와 `output/1450/` 원시 로그에 저장된다. `1450`의
성공은 비교 리포트 생성 성공을 뜻하며, 변환 품질 차이는 리포트의 PASS/WARN/FAIL과 오류 수로 판단한다.
