# 생성 리소스 기록 (wrtp)

이 코드가 AWS에 만드는 리소스 목록. 모두 태그 `Project=wrtp` + 이름 접두 `wrtp-`.
삭제(`bin/9100`)는 여기 적힌 스택만 대상으로 하며, 그 외 리소스는 절대 건드리지 않는다.
실측 목록은 `bin/9000_list-wrtp-resources`(태그 API)로 언제든 확인.

> 상태 표기: [ ] 미생성 · [x] 생성됨. 각 단계 실행 시 갱신한다.

## CloudFormation 스택 (생성 역순으로 삭제)

- [ ] `wrtp-shared-dms-roles` *(조건부, 계정 공유)* — `dms-vpc-role`, `dms-cloudwatch-logs-role`
      ★ teardown 기본 **제외**(다른 DMS 사용과 공유 가능). 우리가 만든 게 아니면 미삭제.
- [ ] `wrtp-network` — VPC, 퍼블릭 서브넷×2, IGW, 라우트테이블, 보안그룹(`wrtp-dms-sg`, `wrtp-rds-sg`)
- [ ] `wrtp-foundation` — S3 버킷(SSE-S3), Secrets(`wrtp-oracle-source`, `wrtp-pg-target`),
      IAM(`wrtp-sc-s3-role`, `wrtp-sc-secrets-role`, `wrtp-dms-assessment-role`)
- [ ] `wrtp-target-postgresql` — DBSubnetGroup, RDS 인스턴스 `wrtp-pg` (★데이터 보유 → 삭제 전 확인)
- [ ] `wrtp-schema-conversion` — DMS InstanceProfile, DataProvider×2, MigrationProject
- [ ] `wrtp-data-migration` — ReplicationSubnetGroup, ReplicationInstance, Endpoint×2, ReplicationTask

## 스택 외 (운영 산출물, AWS 비용 아님)

- S3 객체: 평가 리포트 / 변환 SQL (teardown 시 버킷 비우기 후 버킷 삭제)
- 로컬 `output/`: 다운로드 덤프·로그 (git 미추적)
