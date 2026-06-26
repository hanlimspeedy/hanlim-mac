# 생성 리소스 기록 (wrtp)

이 코드가 AWS에 만드는 리소스 목록. 모두 태그 `Project=wrtp` + 이름 접두 `wrtp-`.
삭제(`bin/9100`)는 여기 적힌 스택만 대상으로 하며, 그 외 리소스는 절대 건드리지 않는다.
실측 목록은 `bin/9000_list-wrtp-resources`(태그 API)로 언제든 확인.

> 상태 표기: [ ] 미생성/삭제됨 · [x] 생성됨. 각 단계 실행 시 갱신한다.
> 현재 실측: 2026-06-26 `9100_teardown-wrtp-resources --apply --delete-rds --include-shared` 완료 후 확인 기준.
> `wrtp-*` CloudFormation stack, DMS, RDS, DMS 로그그룹, EC2 VPC/subnet/security group은 남아 있지 않다.
> Resource Groups Tagging API가 삭제된 `subnet-0f52adf8cadb23aeb` tag를 일시적으로 반환하지만,
> EC2 `describe-subnets`에서는 `InvalidSubnetID.NotFound`이며 실제 리소스는 존재하지 않는다.

## CloudFormation 스택 (생성 역순으로 삭제)

- [ ] `wrtp-shared-dms-roles` *(조건부, 계정 공유)* — `dms-vpc-role`, `dms-cloudwatch-logs-role`
      ★ teardown 기본 **제외**(다른 DMS 사용과 공유 가능). 우리가 만든 게 아니면 미삭제.
      (삭제됨: 이번 실행에서 생성했고 `--include-shared`로 함께 제거)
- [ ] `wrtp-network` — VPC, 퍼블릭 서브넷×2, IGW, 라우트테이블, 보안그룹(`wrtp-dms-sg`, `wrtp-rds-sg`)
      (삭제됨: vpc-0161069390383811d / dms-sg sg-09d6baa40cf3d9122 / rds-sg sg-051f401961131a633)
- [ ] `wrtp-foundation` — S3 버킷(SSE-S3, `wrtp-sc-392007576861-ap-northeast-2`),
      Secrets(`wrtp-oracle-sc`, `wrtp-oracle-dms`, `wrtp-pg-target`),
      IAM(`wrtp-sc-s3-role`, `wrtp-sc-secrets-role`, `wrtp-dms-assessment-role`) (S3 비운 뒤 삭제됨)
- [ ] `wrtp-target-postgresql` — DBSubnetGroup, RDS 인스턴스 `wrtp-pg`
      (삭제됨: endpoint wrtp-pg.cluga42k01u1.ap-northeast-2.rds.amazonaws.com)
- [ ] `wrtp-schema-conversion` — DMS InstanceProfile, DataProvider×2, MigrationProject `wrtp-migration-project`
      (final data-only 경로에서는 미생성)
- [ ] `wrtp-data-migration` — ReplicationSubnetGroup, ReplicationInstance, Endpoint×2, ReplicationTask
      (final data-only 경로에서는 미생성)
      ※ ReplicationTask `MigrationType` 은 `config.env: MIGRATION_TYPE` 로 결정(full-load | full-load-and-cdc).
      ※ CDC 모드면 복제 인스턴스+RDS 가 컷오버(bin/1180)까지 계속 과금 → 1180·1200 후 9100.
- [ ] `wrtp-data-only-migration` — final data-only용 ReplicationSubnetGroup, ReplicationInstance,
      Endpoint×2, ReplicationTask `wrtp-data-only-task`
      ※ 항상 full-load-and-cdc. `sql/data-only/base-table-list.txt`의 base table row만 적재·CDC 적용.
      ※ PostgreSQL-developed schema는 `bin/0550_apply-developed-postgresql-schema`로 repo SQL에서 적용.
      ※ CDC 모드이므로 복제 인스턴스+RDS 가 컷오버(bin/1190)까지 계속 과금 → 1190·1200 후 9100.
      (삭제됨: full-load 11개 base table 완료, `1165` CDC 검증 완료, `1190`에서 task stopped 후 삭제)

## 스택 외 (운영 산출물, AWS 비용 아님)

- S3 객체: 현재 data-only 경로에서는 변환 산출물 업로드 없음. 버킷 비운 뒤 삭제 완료.
- 로컬 `aws-dms/output/`, `output/`: 다운로드 덤프·로그·비교 리포트 (git 미추적, AWS 비용 아님)
- CloudWatch 로그그룹 `dms-tasks-wrtp-dms-ri`, `dms-tasks-wrtp-data-only-dms-ri`,
  `dms-tasks-sct-<projId>` — DMS 자동 생성(CFN 밖).
  `bin/9100` 이 이번 실행분(복제 인스턴스·마이그레이션 프로젝트 기준)을 함께 삭제한다.
  이번 실행분 `dms-tasks-wrtp-data-only-dms-ri` 삭제 완료.
- **Oracle(온프레미스) CDC 변경** — 현재 final data-only 검증을 위해 활성화됨.
  최종 정리 시 `bin/9200 --apply --disable-archivelog`와 `bin/9210 --apply`를 실행해 되돌린다.
