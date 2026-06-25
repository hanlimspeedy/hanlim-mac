# AWS DMS 기반 Oracle → PostgreSQL 마이그레이션 (wrtp)

온프레미스 Oracle 19c(`ORCLPDB1.SAMPLE`)를 **AWS DMS Schema Conversion + AWS DMS**로 PostgreSQL로
변환·적재한 뒤, 그 DB를 **온프레미스로 내려받아** 운영하고, **AWS 리소스는 전부 정리**한다.
이 문서 하나로 전 과정을 재현할 수 있게 유지한다.

- IaC: **CloudFormation** (스택 단위로 "내가 만든 것만" 삭제) · 리전 **ap-northeast-2**
- 방식: **Full Load only** (운영 Oracle 재시작 불필요) · 타깃: **임시 RDS for PostgreSQL 16**
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
| 0150 | `bin/0150_ensure-shared-dms-service-roles` | dms-vpc-role/cloudwatch-logs-role 확인·생성(공유) |
| 0200 | `bin/0200_create-network` | VPC/서브넷/IGW/SG |
| 0300 | `bin/0300_create-foundation-s3-secrets-iam` | S3(SSE-S3)/Secrets/IAM 역할 |
| 0400 | `bin/0400_set-connection-secrets` | Oracle·PG 자격증명 주입(미저장) |
| 0500 | `bin/0500_create-target-postgresql-rds` | 임시 RDS PG16 |
| 0600 | `bin/0600_create-schema-conversion-project` | DMS Schema Conversion |
| 0700 | `bin/0700_run-schema-assessment-report` | 평가 리포트 |
| 0800 | `bin/0800_convert-and-apply-schema-to-target` | 스키마 변환·적용 |
| 0900 | `bin/0900_create-data-migration-task` | DMS full-load 태스크 |
| 1000 | `bin/1000_test-endpoint-connections` | 엔드포인트 연결 테스트 |
| 1100 | `bin/1100_run-full-load-and-validate` | full-load + 검증 |
| 1200 | `bin/1200_download-postgresql-dump` | pg_dump 다운로드 |
| 1300 | `bin/1300_restore-dump-to-onprem-postgresql` | 온프레미스 복원(선택) |
| 9000 | `bin/9000_list-wrtp-resources` | wrtp 리소스 인벤토리(읽기) |
| 9100 | `bin/9100_teardown-wrtp-resources` | 정리(dry-run 기본) |

생성되는 리소스 규칙·목록은 [CREATED_RESOURCES.md](CREATED_RESOURCES.md) 참고.

## 비용 주의

복제 인스턴스·RDS·Schema Conversion 인스턴스는 **시간당 과금**. 다운로드(1200) 직후 `9100`으로 정리한다.
