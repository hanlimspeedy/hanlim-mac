# 생성 리소스 기록 (wrtp)

이 코드가 AWS에 만드는 리소스 목록. 모두 태그 `Project=wrtp` + 이름 접두 `wrtp-`.
삭제(`bin/9100`)는 여기 적힌 스택만 대상으로 하며, 그 외 리소스는 절대 건드리지 않는다.
실측 목록은 `bin/9000_list-wrtp-resources`(태그 API)로 언제든 확인.

> 상태 표기: [ ] 미생성/삭제됨 · [x] 생성됨. 각 단계 실행 시 갱신한다.
> 현재 실측: 2026-06-26 `9100_teardown-wrtp-resources --apply --delete-rds` 완료 기준.

## CloudFormation 스택 (생성 역순으로 삭제)

- [x] `wrtp-shared-dms-roles` *(조건부, 계정 공유)* — `dms-vpc-role`, `dms-cloudwatch-logs-role`
      ★ teardown 기본 **제외**(다른 DMS 사용과 공유 가능). 우리가 만든 게 아니면 미삭제.
      (이번 생성: 기존에 두 역할 **없었음** → 우리가 만든 것이므로 teardown 시 `--include-shared`로 제거 가능.)
- [ ] `wrtp-network` — VPC, 퍼블릭 서브넷×2, IGW, 라우트테이블, 보안그룹(`wrtp-dms-sg`, `wrtp-rds-sg`)
      (삭제됨: vpc-00d2361f81f05713b / dms-sg sg-0c77cbadf4a189ab9 / rds-sg sg-0dea7b87cf76a65cf)
- [ ] `wrtp-foundation` — S3 버킷(SSE-S3, `wrtp-sc-392007576861-ap-northeast-2`),
      Secrets(`wrtp-oracle-sc`, `wrtp-oracle-dms`, `wrtp-pg-target`),
      IAM(`wrtp-sc-s3-role`, `wrtp-sc-secrets-role`, `wrtp-dms-assessment-role`) (삭제됨)
- [ ] `wrtp-target-postgresql` — DBSubnetGroup, RDS 인스턴스 `wrtp-pg`
      (삭제됨: endpoint wrtp-pg.cluga42k01u1.ap-northeast-2.rds.amazonaws.com)
- [ ] `wrtp-schema-conversion` — DMS InstanceProfile, DataProvider×2, MigrationProject `wrtp-migration-project`
      (삭제됨: assessment/export/apply 완료 후 `0850` PostgreSQL 보정까지 검증)
- [ ] `wrtp-data-migration` — ReplicationSubnetGroup, ReplicationInstance, Endpoint×2, ReplicationTask
      (full-load 완료: 13개 테이블, table error 0)
      ※ ReplicationTask `MigrationType` 은 `config.env: MIGRATION_TYPE` 로 결정(full-load | full-load-and-cdc).
      ※ CDC 모드면 복제 인스턴스+RDS 가 컷오버(bin/1180)까지 계속 과금 → 1180·1200 후 9100.

## 스택 외 (운영 산출물, AWS 비용 아님)

- S3 객체: 평가 리포트 / 변환 SQL (teardown에서 버킷 비우기 후 버킷 삭제 완료)
- 로컬 `aws-dms/output/`, `output/`: 다운로드 덤프·로그 (git 미추적, AWS 비용 아님)
