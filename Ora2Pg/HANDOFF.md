# Ora2Pg Handoff

## 목적

이 작업의 1차 목적은 `192.168.29.248`에 있는 Oracle DB를 나중에 PostgreSQL로 이전할 수 있도록, **현재 서버에서 작업 가능한 접속/클라이언트 환경을 만드는 것**이다.

중요:

- 지금 단계의 핵심은 **환경 준비**다.
- `ora2pg`로 실제 추출/변환 작업을 진행하는 것은 다음 단계다.
- 다음 작업자는 **환경 유지보수와 확인 위주로 진행**해야 하며, 실제 마이그레이션 실행은 사용자가 명시적으로 요청할 때만 해야 한다.

## 왜 현재 서버에서 작업해야 하는가

- Oracle 서버 `192.168.29.248`은 사용자가 명시적으로 **느리다**고 했다.
- 따라서 무거운 작업은 가능하면 `248`에서 직접 하지 않고, **현재 서버에서 Oracle client와 ora2pg를 실행**하는 방식으로 진행해야 한다.
- `248`은 Oracle DB가 올라간 원격 서버이고, 현재 서버는 이를 원격으로 접근하는 작업 노드다.

정리:

- 느린 서버: `192.168.29.248`
- 작업 서버: 현재 Codex가 실행 중인 서버
- 원칙: `248`에서는 최소한의 확인과 관리만 수행하고, Oracle 접속/추출/변환 도구는 현재 서버에서 돌린다.

## 현재 확인된 Oracle 구조

- 원격 호스트: `192.168.29.248`
- 원격 OS: Rocky Linux 8.10
- Oracle 버전: 19c
- 인스턴스: `ORCL`
- CDB 여부: `YES`
- 현재 애플리케이션 데이터가 있는 컨테이너: `ORCLPDB1`
- 따라서 **실제 작업 대상은 `CDB$ROOT`가 아니라 `ORCLPDB1`** 이다.

이걸 놓치면 잘못된 컨테이너를 조회하게 된다.

실제로 확인된 상태:

- `CDB$ROOT`에는 업무 테이블이 보이지 않았음
- `ORCLPDB1`로 세션 전환 후 업무 스키마/테이블이 보였음

## 현재 확인된 업무 스키마

테이블명과 row count 기준으로 실제 업무 데이터는 `SAMPLE` 스키마에 있다.

확인된 row count:

- `DEPARTMENTS = 30`
- `EMPLOYEES = 800`
- `PRODUCTS = 3000`
- `CUSTOMERS = 15000`
- `ORDERS = 35000`
- `ORDER_ITEMS = 100000`

즉 다음 작업에서 기본 Oracle 스키마는 `SAMPLE`로 보면 된다.

## 접속 방식

### 1. SSH

현재 서버에서 `248`로 **SSH 키 기반 접속**이 설정되어 있다.

사용 스크립트:

- [bin/ssh-248](/home/ubuntu/root/Ora2Pg/bin/ssh-248:1)

의미:

- 더 이상 비밀번호 입력 없이 `root@192.168.29.248` 접속 가능
- 초기 부트스트랩용 비밀번호 정보는 [.env](/home/ubuntu/root/Ora2Pg/.env:1)에 있었지만, 현재는 일상 작업에서 직접 쓸 필요가 거의 없다

### 2. Oracle 접속

현재 서버에 Oracle Instant Client와 `sqlplus`가 설치되어 있고, `248`의 `ORCLPDB1`로 직접 접속 가능하다.

현재 서버에서 사용하는 핵심 값:

- Host: `192.168.29.248`
- Port: `1521`
- Service: `ORCLPDB1`
- Schema: `SAMPLE`

환경 파일:

- [.oracle.env](/home/ubuntu/root/Ora2Pg/.oracle.env:1)

중요:

- `ORCL`로 붙으면 CDB root를 보게 될 수 있으므로, 일반 작업 대상 서비스는 `ORCLPDB1`이다.

## 현재 서버에 설치된 것

### Oracle client

- 설치 위치: `/opt/oracle/instantclient_19_31`
- ZIP 원본:
  - [downloads/instantclient-basic-linux.x64-19.31.0.0.0dbru.zip](/home/ubuntu/root/Ora2Pg/downloads/instantclient-basic-linux.x64-19.31.0.0.0dbru.zip:1)
  - [downloads/instantclient-sqlplus-linux.x64-19.31.0.0.0dbru.zip](/home/ubuntu/root/Ora2Pg/downloads/instantclient-sqlplus-linux.x64-19.31.0.0.0dbru.zip:1)
  - [downloads/instantclient-sdk-linux.x64-19.31.0.0.0dbru.zip](/home/ubuntu/root/Ora2Pg/downloads/instantclient-sdk-linux.x64-19.31.0.0.0dbru.zip:1)

### Perl / Ora2Pg 관련

- `DBD::Oracle` 설치됨
- `DBD::Pg` 설치됨
- `ora2pg` 설치됨
- 설치 경로는 사용자 로컬 Perl 경로(`/home/ubuntu/perl5`)를 사용

## 만들어 둔 스크립트

### 공통 환경

- [bin/env.sh](/home/ubuntu/root/Ora2Pg/bin/env.sh:1)
  - 현재 서버에서 Oracle client, Perl, TNS, ora2pg 경로를 잡는다.
  - `.oracle.env`를 자동 로드한다.

### 원격 SYSDBA 실행

- [bin/run-remote-sqlplus-sysdba](/home/ubuntu/root/Ora2Pg/bin/run-remote-sqlplus-sysdba:1)
  - 로컬 SQL 파일을 원격 `248`에 복사
  - `oracle` OS 사용자로 `/ as sysdba` 실행
  - 필요하면 `ORACLE_SYS_CONTAINER` 값으로 자동 `alter session set container=...` 수행

중요:

- 이 스크립트 덕분에 원격 Oracle 관리 작업도 1회성 ad-hoc 명령 대신 **버전 관리 가능한 SQL 파일 기반**으로 실행할 수 있다.

### 직접 Oracle 접속

- [bin/sqlplus-248](/home/ubuntu/root/Ora2Pg/bin/sqlplus-248:1)
  - 현재 서버에서 Oracle 계정으로 직접 `sqlplus` 접속

- [bin/test-oracle](/home/ubuntu/root/Ora2Pg/bin/test-oracle:1)
  - 현재 서버에서 Oracle 계정 접속 테스트

### ora2pg 실행

- [bin/ora2pg-run](/home/ubuntu/root/Ora2Pg/bin/ora2pg-run:1)
  - 템플릿 기반으로 설정 파일을 렌더링한 뒤 `ora2pg` 실행

주의:

- 이 스크립트는 이미 준비되어 있지만, **사용자가 명시적으로 요청하기 전에는 실제 마이그레이션/추출 작업에 쓰지 말 것**

## 단계형 스크립트

다음 작업자가 재현성 있게 한 단계씩 검증할 수 있도록 단계 스크립트를 만들었다.

- [bin/step-01-check-ssh](/home/ubuntu/root/Ora2Pg/bin/step-01-check-ssh:1)
  - SSH 접속 확인
- [bin/step-02-check-db-state](/home/ubuntu/root/Ora2Pg/bin/step-02-check-db-state:1)
  - DB 인스턴스 상태 확인
- [bin/step-03-list-containers](/home/ubuntu/root/Ora2Pg/bin/step-03-list-containers:1)
  - CDB/PDB 구조 확인
- [bin/step-04-list-schemas](/home/ubuntu/root/Ora2Pg/bin/step-04-list-schemas:1)
  - PDB 안의 비시스템 스키마 개요 확인
- [bin/step-05-find-business-tables](/home/ubuntu/root/Ora2Pg/bin/step-05-find-business-tables:1)
  - 업무 테이블명이 어느 스키마에 있는지 확인
- [bin/step-06-profile-business-schema](/home/ubuntu/root/Ora2Pg/bin/step-06-profile-business-schema:1)
  - 대상 스키마의 실제 row count 확인
- [bin/step-07-create-ora2pg-user](/home/ubuntu/root/Ora2Pg/bin/step-07-create-ora2pg-user:1)
  - Ora2Pg용 Oracle 계정 생성/갱신
- [bin/step-08-test-oracle-login](/home/ubuntu/root/Ora2Pg/bin/step-08-test-oracle-login:1)
  - 현재 서버에서 해당 계정으로 직접 Oracle 접속 확인
- [bin/step-09-ora2pg-show-report](/home/ubuntu/root/Ora2Pg/bin/step-09-ora2pg-show-report:1)
  - Ora2Pg 리포트 실행

중요:

- 사용자가 명시적으로 요구한 작업 방식은 **한 번에 한 단계씩**이다.
- 병렬 실행 금지
- 여러 단계를 묶은 일괄 실행 금지
- 한 단계 실패 시, 같은 단계의 스크립트나 설정을 수정한 뒤 **같은 단계부터 재실행**

## SQL 템플릿 / 점검 파일

- [sql/01_show_db_state.sql](/home/ubuntu/root/Ora2Pg/sql/01_show_db_state.sql:1)
- [sql/02_list_containers.sql](/home/ubuntu/root/Ora2Pg/sql/02_list_containers.sql:1)
- [sql/02_list_candidate_schemas.sql](/home/ubuntu/root/Ora2Pg/sql/02_list_candidate_schemas.sql:1)
- [sql/03_find_business_tables.sql](/home/ubuntu/root/Ora2Pg/sql/03_find_business_tables.sql:1)
- [sql/04_profile_business_schema.sql.template](/home/ubuntu/root/Ora2Pg/sql/04_profile_business_schema.sql.template:1)
- [sql/02_create_ora2pg_user.sql.template](/home/ubuntu/root/Ora2Pg/sql/02_create_ora2pg_user.sql.template:1)

원칙:

- Oracle 관리 작업은 가능하면 이 SQL 파일/템플릿을 수정해서 진행한다.
- 원격에 들어가 즉석 SQL을 치는 방식은 피한다.

## 현재 확정된 설정값

현재 [.oracle.env](/home/ubuntu/root/Ora2Pg/.oracle.env:1)에 반영된 기준:

- `ORACLE_HOST=192.168.29.248`
- `ORACLE_PORT=1521`
- `ORACLE_SERVICE=ORCLPDB1`
- `ORACLE_SYS_CONTAINER=ORCLPDB1`
- `ORA_SCHEMA=SAMPLE`

또한 Ora2Pg용 Oracle 계정도 생성되어 있다:

- `ORA2PG_MIG`

계정 비밀번호와 실제 접속용 상세 값은 `.oracle.env`를 직접 확인하면 된다.

## 현재까지 검증 완료된 것

- SSH 키 기반 접속 성공
- 원격 Oracle 인스턴스 상태 확인 성공
- `CDB$ROOT` / `ORCLPDB1` 구조 확인 성공
- 실제 업무 데이터가 `ORCLPDB1.SAMPLE`에 있음을 확인
- row count가 사용자가 제시한 적재 결과와 일치함을 확인
- Ora2Pg용 Oracle 사용자 생성 성공
- 현재 서버의 Oracle client로 해당 사용자 접속 성공

## 다음 작업자가 실수하기 쉬운 지점

### 1. CDB root를 보면 안 된다

- `ORCL` 인스턴스만 보고 작업하면 `CDB$ROOT`를 보게 될 수 있다.
- 실제 데이터는 `ORCLPDB1`에 있다.

### 2. 느린 서버에서 직접 무거운 작업을 하지 말아야 한다

- `248`은 느리므로, 추출/변환은 현재 서버에서 수행하는 방향이 맞다.

### 3. ad-hoc 명령보다 스크립트/문서 우선

- 사용자는 반복 가능성과 재현 가능성을 가장 중요하게 본다.
- 새 작업이 필요하면 먼저 스크립트나 SQL 템플릿으로 만들고, 문서도 같이 갱신해야 한다.

### 4. 범위를 넘는 실행을 먼저 하면 안 된다

- 사용자 요청은 현재까지 **환경 구성**이 중심이었다.
- 다음 작업자는 사용자가 명시적으로 요청하지 않으면 `ora2pg` 본 실행, 대량 export, PostgreSQL 적재를 먼저 진행하면 안 된다.

## 마이그레이션 호환성 테스트 (완료, step-10~23)

사용자 요청으로 **PostgreSQL vs IvorySQL 이중 타깃 호환성 테스트**를 수행했다. 전체 재현 절차와
설계 이유는 [MIGRATION_TEST.md](/home/ubuntu/root/Ora2Pg/MIGRATION_TEST.md:1)에 있다(기억 없는 AI도 이 문서만으로 재현 가능).

구성:

- PostgreSQL 16: **네이티브 apt**, `127.0.0.1:5432`, DB `sample_pg`
- IvorySQL 3.4(PG16 기반): **Docker** `ivorysql/ivorysql:3.4-ubi8`, `127.0.0.1:5433`, DB `sample_ivory`
- 두 타깃 모두 **UTF8 + C collation**(한글 안전 + Ora2Pg 검증 정합)
- Oracle `SAMPLE`를 Ora2Pg로 한 번 추출(`output/export/`) → 동일 산출물을 양쪽에 적재 → 비교

결과 (`output/COMPATIBILITY_REPORT.md`) — **풍부한 SAMPLE 스키마**(테이블 11+파티션, 시퀀스 6, 함수/프로시저/패키지,
트리거 6, 뷰 7, MVIEW 2, identity/생성컬럼/LOB/RANGE 파티셔닝) 기준:

- **데이터**: 두 타깃 모두 적재 오류 0, 행 수 100% 일치(customers 15000 / order_items 100600 / orders 35300 등).
- **스키마(PLSQL/DDL)**: PG·IvorySQL **둘 다 9 적재오류 + 23 구조 DIFF — 완전히 동일**.
- **핵심 결론: 이 Ora2Pg 경로에서는 PostgreSQL ≈ IvorySQL.** Ora2Pg가 오라클→PostgreSQL 문법으로 먼저 변환하므로
  두 타깃이 같은 산출물을 받고, IvorySQL의 오라클 호환 엔진이 작동할 기회가 없다. 남은 오류는 둘 다 거부하는
  Ora2Pg 변환 한계(COMPOUND TRIGGER, RATIO_TO_REPORT, 패키지 컬렉션 타입, varchar GIN, dblink 감사 트리거 등).
- **IvorySQL 진짜 강점을 보려면** Ora2Pg 없이 오라클 원본 DDL/PLSQL을 IvorySQL 오라클 모드에 직접 적재하는
  별도 경로가 필요(현재 미구현, 다음 단계 후보).

주의(재현 시 핵심):

- **오라클 스키마 재생성 후 `step-07` 재실행 필수**: 테이블 drop/recreate 시 SELECT 권한이 사라져 데이터 export가 빈 파일이 됨.
  순서: `clean-conversion` → `step-07` → `step-15` → … → `step-23`.
- Oracle 계정에 `FLASHBACK ANY TABLE` 필요(Ora2Pg가 `AS OF SCN` 사용). `sql/02` 템플릿에 반영됨.
- 데이터 export는 `PG_DSN=""`로 파일 추출(아니면 PG로 직접 스트리밍됨).
- FK는 `FKEY_DEFERRABLE 1`+`DEFER_FKEY 1`(deferred), 트리거는 `DISABLE_TRIGGERS USER`로 적재 중 비활성화
  (오라클 자율트랜잭션 감사 트리거가 dblink로 변환돼 COPY마다 실패하던 문제 해결). 느린 Oracle 대비 `ORACLE_COPIES 4` 병렬.
- `SCHEMA_TYPES`(step-15)는 sequence/table/**partition**/function/procedure/package/view/mview/trigger/synonym. PARTITION 빠지면 데이터 COPY 전부 실패.
- 깨끗이 다시 적재하려면 `bin/reset-target pg|ivory` 후 step-17~20 재실행. **전체 초기화**는 `bin/clean-conversion`.

## 권장 시작점

다른 AI가 이어받을 때는 아래 순서로 확인하면 된다.

1. [HANDOFF.md](/home/ubuntu/root/Ora2Pg/HANDOFF.md:1) 읽기
2. [README.md](/home/ubuntu/root/Ora2Pg/README.md:1) 읽기
3. [MIGRATION_TEST.md](/home/ubuntu/root/Ora2Pg/MIGRATION_TEST.md:1) 읽기 (마이그레이션 테스트 재현용)
4. [.oracle.env](/home/ubuntu/root/Ora2Pg/.oracle.env:1) 확인
5. 필요 시 `bin/step-01`부터 원하는 단계까지만 순차 실행 (step-10~23은 호환성 테스트)

