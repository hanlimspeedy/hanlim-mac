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
| Oracle 계정에 `FLASHBACK ANY TABLE` 부여 (`sql/02`) | Ora2Pg 데이터 export가 일관 스냅샷을 위해 `SELECT ... AS OF SCN` 사용 → flashback 권한 필요(없으면 ORA-01031). |
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
| 15 | `bin/step-15-export-schema` | Oracle 스키마 DDL → `output/export/schema/` | `01_table.sql` 생성, FK에 `DEFERRABLE` 포함 |
| 16 | `bin/step-16-export-data` | Oracle 데이터 → `output/export/data/01_data.sql` | `^COPY` 다수, 4행에 `SET CONSTRAINTS ALL DEFERRED` |
| 17 | `bin/step-17-load-schema-pg` | 스키마 → PostgreSQL | `RESULT: PASS (0 errors)` |
| 18 | `bin/step-18-load-data-pg` | 데이터 → PostgreSQL | `RESULT: PASS (0 errors)` |
| 19 | `bin/step-19-load-schema-ivory` | 스키마 → IvorySQL | `RESULT: PASS (0 errors)` |
| 20 | `bin/step-20-load-data-ivory` | 데이터 → IvorySQL | `RESULT: PASS (0 errors)` |
| 21 | `bin/step-21-validate-pg` | Ora2Pg TYPE=TEST: Oracle vs PG | 전 항목 `OK, Oracle and PostgreSQL have the same number` |
| 22 | `bin/step-22-validate-ivory` | Ora2Pg TYPE=TEST: Oracle vs IvorySQL | 동일 |
| 23 | `bin/step-23-compatibility-report` | 종합 리포트 생성 | `output/COMPATIBILITY_REPORT.md` 작성 |

> 참고: step-15/16/21/22는 느린 Oracle(`192.168.29.248`)에 붙어 수십 초~분이 걸릴 수 있다. 정상이다.

## 4. 재실행 / 초기화

- **타깃을 깨끗이 비우고 다시 적재**하려면: `bin/reset-target pg` 또는 `bin/reset-target ivory`
  (해당 DB를 DROP 후 create step 재실행). 그 다음 step-17~20을 다시 돌린다.
- **임의 타깃에 직접 psql** 접속: `bin/pg-psql pg ...` / `bin/pg-psql ivory ...`
- IvorySQL 컨테이너 중지/삭제: `docker stop ora2pg-ivory` / `docker rm -f ora2pg-ivory` (step-12가 다시 만든다).

## 5. 결과 읽는 법

- 종합: [output/COMPATIBILITY_REPORT.md](output/COMPATIBILITY_REPORT.md)
  - §2 적재 오류 수(0이 최선), §3 행 수 일치(Oracle=PG=IvorySQL), §4 구조검증(OK 항목 수 / 불일치 수).
- 상세 적재 로그: `output/load/{pg,ivory}-{schema,data}.log` (파일별 오류 나열).
- 상세 구조검증: `output/21_validate_pg.txt`, `output/22_validate_ivory.txt`.

## 6. 현재까지의 결과 요약

`SAMPLE` 스키마(테이블 6, 인덱스, check/FK 제약, **PL/SQL·패키지·시퀀스·뷰 없음**) 기준:

- PostgreSQL, IvorySQL **둘 다 적재 오류 0**, 행 수 100% 일치(customers 15000 / departments 30 / employees 800 /
  orders 35000 / order_items 100000 / products 3000), 구조검증 19개 항목 모두 OK.
- 즉 **이 스키마에서는 두 DB의 호환성 차이가 드러나지 않는다.**
- 단, IvorySQL은 `enable_emptystring_to_NULL=on`, `database_mode=oracle` 등 **오라클 의미를 엔진에 내장**(step-14 출력).
  순정 PostgreSQL은 빈 문자열을 NULL로 취급하지 않는다. 따라서 **오라클 PL/SQL·내장 함수·빈문자열 의존 코드가 많을수록
  IvorySQL이 유리**해질 가능성이 크다.

## 7. 한계와 다음 단계

- 깊은 호환성 차이(PL/SQL 자동변환, 패키지, 익명 블록, `NVL/DECODE/SYSDATE` 등 오라클 함수, 빈문자열 의미)는
  **PL/SQL을 포함한 스키마**로 다시 테스트해야 드러난다. 이 하니스는 그대로 재사용 가능하다
  (`SCHEMA_TYPES` 환경변수로 `step-15`에 FUNCTION/PROCEDURE/PACKAGE/TRIGGER/VIEW 등을 추가).
- 순정 PostgreSQL 경로를 더 공정하게 보려면 `orafce` 확장을 PG에 설치해 비교할 수 있다(IvorySQL은 내장).
- 저다운타임 컷오버는 Ora2Pg(오프라인) 범위 밖이며 별도 CDC 도구(Debezium/SymmetricDS) 설계가 필요하다.
