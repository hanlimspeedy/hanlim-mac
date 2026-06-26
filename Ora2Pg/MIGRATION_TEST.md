# 마이그레이션 호환성 테스트 (PostgreSQL vs IvorySQL)

이 문서 하나만 읽고도 **관련 기억이 전혀 없는 사람/AI가 step-10~23을 그대로 재현**할 수 있도록 작성했다.
먼저 [HANDOFF.md](HANDOFF.md)(전체 맥락)와 [README.md](README.md)(스크립트 목록)를 보면 좋지만, 실행 자체는 이 문서로 충분하다.

## 0. 목적

라이선스 비용이 없는 오픈소스 DB로 Oracle을 이전할 때 **PostgreSQL과 IvorySQL 중 어느 쪽이 더 잘 옮겨지는지**를
실측 비교한다. 방법은 단순하다: **Oracle `SAMPLE` 스키마를 Ora2Pg로 한 번만 추출**한 뒤, **그 동일한 산출물을
두 DB에 각각 적재**하고 적재 오류·행 수·구조를 비교한다. 입력이 같으니 차이는 곧 타깃 DB의 호환성 차이다.

```
                        ┌─ (step 15/16) Ora2Pg export ─┐   동일 산출물
 Oracle 19c SAMPLE ─────┤                              ├──► output/export/{schema,data}
 (192.168.29.248)       └──────────────────────────────┘        │
                                                                 ├─(17/18)─► PostgreSQL  (native apt, :5432, DB=sample_pg)
                                                                 └─(19/20)─► IvorySQL    (docker,      :5433, DB=sample_ivory)
                                            (21/22) Ora2Pg TYPE=TEST 구조검증 ─┘
                                            (23) output/COMPATIBILITY_REPORT.md
```

## 1. 전제 조건

- step-01~09 가 이미 끝나 있어야 한다(SSH, Oracle client, Ora2Pg 설치, `ORA2PG_MIG` 계정, Oracle 측 평가).
  안 되어 있으면 [README.md](README.md) "First use" 순서대로 먼저 진행한다.
- 이 작업 서버에 **Docker**와 **sudo**(무암호)가 있어야 한다. PostgreSQL 클라이언트(`psql`)는 이미 설치돼 있다.
- 접속/비밀값은 모두 [.oracle.env](.oracle.env)(gitignore됨)에 있다. 새로 만들 때는 [.oracle.env.example](.oracle.env.example)을 복사해 채운다.

### .oracle.env 의 타깃 변수 (이번 작업에서 추가됨)

```
# PostgreSQL (네이티브 apt)
PG_HOST=127.0.0.1  PG_PORT=5432  PG_DB=sample_pg
PG_APP_USER=ora2pg_app   PG_APP_PASSWORD=...

# IvorySQL (docker)
IVY_HOST=127.0.0.1 IVY_PORT=5433 IVY_DB=sample_ivory
IVY_SUPERUSER=ivorysql   IVY_PASSWORD=...
IVY_IMAGE=ivorysql/ivorysql:3.4-ubi8   IVY_CONTAINER=ora2pg-ivory
```

`bin/env.sh`가 이 값들을 자동 로드하며, 비어 있으면 위와 같은 기본값을 쓴다.

## 2. 핵심 설계 결정 (왜 이렇게 했는가 — 재현 시 반드시 이해할 것)

| 결정 | 이유 |
|---|---|
| PostgreSQL은 native apt, IvorySQL은 docker | IvorySQL은 Ubuntu apt 패키지가 없어 docker가 유일하게 깔끔. PG는 향후 managed PG 배포에 가깝게 native. |
| IvorySQL **3.4 (PG16 기반)** 선택 | `postgresql-16`과 PG 베이스를 맞춰 차이를 "오라클 호환 계층" 차이로만 해석. 이미지 태그는 변수라 나중에 최신으로 교체 가능. |
| 두 타깃 모두 **UTF8 + C collation** 로 통일 | 한글(멀티바이트) 안전 + Ora2Pg 데이터 검증이 Oracle 이진 정렬과 맞으려면 C가 유리. 컨테이너 기본은 SQL_ASCII/C 라 반드시 재지정. (`sql/10`,`sql/11` 템플릿) |
| Ora2Pg `STOP_ON_ERROR 0` | 적재 시 첫 오류에서 멈추지 않고 끝까지 가서 **모든 오류를 수집** → 호환성 측정 정확. |
| Ora2Pg `FKEY_DEFERRABLE 1` + `DEFER_FKEY 1` | 데이터 export가 테이블 알파벳순이라 `order_items`가 참조 대상 `products`보다 먼저 온다. FK를 deferrable로 만들고 데이터 적재 트랜잭션에서 `SET CONSTRAINTS ALL DEFERRED` → COMMIT 시점에 검사하므로 적재 순서 무관. 슈퍼유저 불필요. |
| Ora2Pg `DISABLE_TRIGGERS USER` | 스키마에 오라클 자율트랜잭션 감사 트리거(Ora2Pg가 dblink 기반으로 변환)가 있으면 데이터 COPY마다 트리거가 발화→dblink 없어 실패→트랜잭션 전체 롤백. 데이터 적재 동안 `ALTER TABLE ... DISABLE TRIGGER USER`(소유자 권한, 슈퍼유저 불필요)로 끈다. 대량 적재 표준 관행. |
| Ora2Pg `ORACLE_COPIES 4` | 원격 Oracle(`248`)이 느려 LOB 포함 데이터 export가 라운드트립에 묶여 느리다(직렬 ~30 recs/s). 병렬 읽기 연결로 라운드트립을 겹쳐 수배 빨라짐. |
| Oracle 계정에 `FLASHBACK ANY TABLE` 부여 (`sql/02`) | Ora2Pg 데이터 export가 일관 스냅샷을 위해 `SELECT ... AS OF SCN` 사용 → flashback 권한 필요(없으면 ORA-01031). |
| **스키마 재생성 후 `step-07` 재실행 필수** | 오라클에서 테이블을 drop/recreate 하면 `ORA2PG_MIG`의 SELECT 권한이 사라진다. step-07(=`grant select on dba_tables for SAMPLE`)을 다시 돌려야 데이터 export가 된다. (스키마 DDL export는 dictionary로 되지만 데이터 export는 직접 SELECT 권한 필요.) |
| `SCHEMA_TYPES` (step-15) 에 PL/SQL·PARTITION 포함 | 풍부한 스키마는 sequence/table/**partition**/function/procedure/package/view/mview/trigger/synonym 를 모두 export 해야 한다. 특히 PARTITION 을 빼면 파티션 자식 테이블(p2018…pmax)이 안 생겨 데이터 COPY가 전부 실패한다. 0개인 타입은 빈 파일이라 무해. |
| 두 타깃에 `sample` 역할 생성 | Ora2Pg가 스키마 소유자를 원본 Oracle 소유자(`sample`)로 지정. 같은 export를 두 타깃에 그대로 넣으려면 양쪽에 역할이 있어야 함. PG는 app 유저를 이 역할 멤버로. |
| 데이터 export 시 `PG_DSN=""` | Ora2Pg는 `TYPE=COPY`에 PG_DSN이 있으면 PG로 **직접 스트리밍**한다. 파일로 뽑으려면 PG_DSN을 비워야 함(`bin/ora2pg-run`은 빈 값을 그대로 둔다). |

## 3. 단계별 실행 (반드시 한 번에 한 단계, 성공 후 다음)

모든 스크립트는 `bin/` 안에 있고 인자 없이 실행한다. 실패하면 **해당 step 스크립트/템플릿을 고치고 같은 step을 다시 실행**한다.

| step | 명령 | 하는 일 | 성공 기준 |
|---|---|---|---|
| 10 | `bin/step-10-install-postgres` | `postgresql-16` 설치(멱등) + 기동 | `OK: PostgreSQL 16 server is reachable` |
| 11 | `bin/step-11-create-pg-target` | 역할 `ora2pg_app`, `sample` + DB `sample_pg`(UTF8/C) | `OK: role ... and database sample_pg ready` |
| 12 | `bin/step-12-start-ivorysql` | IvorySQL 컨테이너 기동(없으면 pull/run) | `OK: IvorySQL container ... reachable on port 5433` |
| 13 | `bin/step-13-create-ivory-target` | DB `sample_ivory`(UTF8/C) + `sample` 역할 | `OK: database sample_ivory ready` |
| 14 | `bin/step-14-check-targets` | 두 타깃 버전/인코딩 + IvorySQL 오라클 호환 설정 | 둘 다 `encoding=UTF8 collate=C`, `OK: both targets reachable` |
| (07) | `bin/step-07-create-ora2pg-user` | **오라클 스키마를 재생성했다면 먼저** SELECT/FLASHBACK 권한 재부여 | `Grant succeeded` 반복 |
| 15 | `bin/step-15-export-schema` | Oracle 스키마 DDL → `output/export/schema/` (sequence/table/partition/function/procedure/package/view/mview/trigger/synonym) | `0N_*.sql` 생성, FK에 `DEFERRABLE`, `03_partition.sql`에 `PARTITION OF` |
| 16 | `bin/step-16-export-data` | Oracle 데이터 → `output/export/data/01_data.sql` | `^COPY` 다수, `SET CONSTRAINTS ALL DEFERRED` + `DISABLE TRIGGER USER` 포함 |
| 17 | `bin/step-17-load-schema-pg` | 스키마 → PostgreSQL | 적재 완료(풍부한 스키마는 Ora2Pg 변환 한계로 일부 ERROR 발생 — 측정 대상. 양 타깃 동일해야 함) |
| 18 | `bin/step-18-load-data-pg` | 데이터 → PostgreSQL | `RESULT: PASS (0 errors)` |
| 19 | `bin/step-19-load-schema-ivory` | 스키마 → IvorySQL | step-17과 동일한 오류 수 |
| 20 | `bin/step-20-load-data-ivory` | 데이터 → IvorySQL | `RESULT: PASS (0 errors)` |
| 21 | `bin/step-21-validate-pg` | Ora2Pg TYPE=TEST: Oracle vs PG | `OK,...` 다수 + 변환 안 된 객체는 `DIFF:` 로 표기 |
| 22 | `bin/step-22-validate-ivory` | Ora2Pg TYPE=TEST: Oracle vs IvorySQL | step-21과 동일 결과 |
| 23 | `bin/step-23-compatibility-report` | 종합 리포트 생성 | `output/COMPATIBILITY_REPORT.md` 작성 |

> 참고: step-15/16/21/22는 느린 Oracle(`192.168.29.248`)에 붙어 수십 초~분이 걸릴 수 있다. 정상이다.
> 데이터 export(step-16)는 LOB 때문에 특히 느려 `ORACLE_COPIES 4` 병렬로 단축한다.
> **풍부한 스키마에서는 step-17/19에 ERROR가 나는 것이 정상이다**(Ora2Pg가 변환하지 못한 오라클 구문). 핵심은 PG와 IvorySQL의 오류·DIFF 수가 같은지다.

## 4. 재실행 / 초기화

- **전체 초기화(추출물 + 두 타깃 모두)**: `bin/clean-conversion`
  - `output/`의 모든 생성물(추출 파일·적재 로그·검증·리포트)을 지우고, `sample_pg`·`sample_ivory`를
    DROP 후 빈 상태로 재생성한다.
  - **Oracle 샘플 스키마를 다시 만든 뒤** 순서: `bin/clean-conversion` → `bin/step-07-create-ora2pg-user`(권한 재부여) → `step-15` → … → `step-23`.
    step-07을 건너뛰면 테이블 재생성으로 SELECT 권한이 사라져 데이터 export(step-16)가 빈 파일이 된다.
  - 전제: PostgreSQL(step-10)과 IvorySQL 컨테이너(step-12)가 떠 있어야 한다.
- **한쪽 타깃만 비우고 다시 적재**하려면: `bin/reset-target pg` 또는 `bin/reset-target ivory`
  (해당 DB를 DROP 후 create step 재실행). 그 다음 step-17~20을 다시 돌린다.
- **임의 타깃에 직접 psql** 접속: `bin/pg-psql pg ...` / `bin/pg-psql ivory ...`
- IvorySQL 컨테이너 중지/삭제: `docker stop ora2pg-ivory` / `docker rm -f ora2pg-ivory` (step-12가 다시 만든다).

## 5. 결과 읽는 법

- 종합: [output/COMPATIBILITY_REPORT.md](output/COMPATIBILITY_REPORT.md)
  - §2 적재 오류 수(0이 최선), §3 행 수 일치(Oracle=PG=IvorySQL), §4 구조검증(OK 항목 수 / 불일치 수).
- 상세 적재 로그: `output/load/{pg,ivory}-{schema,data}.log` (파일별 오류 나열).
- 상세 구조검증: `output/21_validate_pg.txt`, `output/22_validate_ivory.txt`.

## 6. 결과 요약 (풍부한 SAMPLE 스키마)

대상 스키마: 테이블 11(파티션 포함), 시퀀스 6, 함수 2, 프로시저 3, 패키지 3, 트리거 6, 뷰 7,
머티리얼라이즈드 뷰 2, 시노님 1, **identity/생성컬럼/LOB/RANGE 파티셔닝** 포함.

- **데이터**: 두 타깃 모두 적재 오류 0, 행 수 100% 일치
  (customers 15000 / departments 30 / employees 810 / products 3001 / order_items 100600 /
  orders 35300 / audit_log 314 / region_dim 6 / tax_rates 6 / employee_targets 154 / order_status_dim 7).
- **스키마(DDL/PLSQL)**: PG·IvorySQL **둘 다 9개 적재 오류, 23개 구조 DIFF — 완전히 동일**.
- **핵심 결론**: 이 Ora2Pg 경로에서는 **PostgreSQL ≈ IvorySQL**. Ora2Pg가 오라클 문법을 PostgreSQL 문법으로
  **먼저 변환**하므로 두 타깃이 같은 결과물을 받고, IvorySQL의 오라클 호환 엔진은 작동할 기회가 없다.
  남은 오류는 둘 다 거부하는 Ora2Pg 변환 한계다: COMPOUND TRIGGER, `RATIO_TO_REPORT`, 패키지 컬렉션 타입,
  varchar 비트맵→GIN 인덱스, dblink 기반 자율트랜잭션 감사 트리거, 일부 패키지 프로시저(place_order), MVIEW.

## 7. 한계와 다음 단계

- **IvorySQL의 진짜 강점은 이 경로로는 측정되지 않는다.** 확인하려면 Ora2Pg를 거치지 않고
  **오라클 원본 DDL/PLSQL을 IvorySQL 오라클 모드(`ivorysql.database_mode=oracle`)에 직접 적재**하는
  별도 경로를 설계해 비교해야 한다(현재 하니스 미구현).
- 순정 PostgreSQL 경로를 더 공정하게 보려면 `orafce` 확장을 PG에 설치해 비교할 수 있다(IvorySQL은 내장).
- 공통 수동 보정 대상: 패키지 프로시저 일부, 머티리얼라이즈드 뷰, 오라클 분석함수(RATIO_TO_REPORT) 뷰,
  varchar GIN 인덱스, 자율트랜잭션 감사 트리거(dblink 설치 또는 재설계).
- 저다운타임 컷오버는 Ora2Pg(오프라인) 범위 밖이며 별도 CDC 도구(Debezium/SymmetricDS) 설계가 필요하다.

## 8. 데이터 전용(data-only) 경로 (steps 24–29)

AWS DMS data-only 경로와 같은 개념을 Ora2Pg로 재현: **손으로 다듬은 PostgreSQL 스키마를 따로 적용**하고
**base table 행 데이터만 1회 적재**(`TYPE=COPY`). 전체변환 결과(`sample_pg`/`sample_ivory`) 보존을 위해
전용 DB `sample_pg_dataonly`/`sample_ivory_dataonly`에 적재한다. 개발 스키마·base table 목록·MV refresh·
시퀀스 보정은 AWS 경로와 **동일 자산을 `aws-dms/sql/data-only/`에서 그 자리 참조**(단일 소스, 복제 없음).

실행(한 번에 한 단계, 타깃별): `step-24`(전용 DB 생성) → `step-25`(개발 스키마 적용) →
`step-26`(base-table COPY 데이터 준비) → `step-27`(적재) → `step-28`(시퀀스+MV) →
`step-29`(Oracle 대비 행수 검증, PASS).

설계 결정 / 주의:
- **전용 DB**: 모든 단계가 `sample_pg_dataonly`/`sample_ivory_dataonly`만 대상. `.oracle.env`가 `PG_DB`/`IVY_DB`를
  하드코딩하고 자식이 `env.sh`를 재source하므로, 헬퍼 env override 대신 각 단계가 전용 DB명으로 **직접 psql**한다.
- **step-26 재사용**: SAMPLE은 base table만 데이터가 있어 step-16의 전체 `TYPE=COPY` 추출본을 재사용(느린 원격
  Oracle 재추출 회피). orders는 Oracle 파티션명(p2018…)으로 COPY되므로 **부모 `orders`로 라우팅** 치환
  (개발 스키마 파티션명 무관, PostgreSQL이 order_date로 분배).
- **step-27 적재**: 개발 스키마의 비-deferrable FK(자기참조 `employees.manager_id` 포함)와 감사 트리거를
  우회하려고 **superuser + `session_replication_role=replica`**로 적재(AWS와 동일 원리). 데이터는 Oracle에서 정합.
- **pgcrypto**: 개발 스키마에 선언만 있고 미사용. pg는 trusted 확장이라 app user가 설치, IvorySQL 컨테이너는
  contrib 미포함이라 `step-25`가 ivory에서만 해당 `CREATE EXTENSION` 라인을 제거하고 나머지는 엄격 적용한다.
- **CDC 미지원**: Ora2Pg는 증분 동기화 불가(§7). data-only는 1회 적재까지가 범위.
