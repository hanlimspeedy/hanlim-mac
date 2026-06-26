# AWS DMS → 온프레미스 Oracle 접속 가이드

AWS(DMS / DMS Schema Conversion)에서 공유기 뒤의 이 Oracle 서버에 접속해 변환·마이그레이션
하기 위한 **접속 정보·계정·전제조건**을 정리한다. 보안(IP 제한 등)은 별도 관리.

## 1. 환경 요약

| 항목 | 값 |
|---|---|
| DB | Oracle 19c **CDB(멀티테넌트)**, 인스턴스 `ORCL` |
| PDB(업무 데이터) | **`ORCLPDB1`** (SAMPLE 스키마: 15 테이블, 102 객체) |
| 리스너 | TCP **1521** (0.0.0.0) |
| 공인 IP(접속 대상) | **<PUBLIC_IP>** ※ 가정용 → **유동일 수 있음**(바뀌면 DMS 엔드포인트 수정 또는 DDNS) |
| 포트포워딩 | 외부 1521 → 내부 `192.168.29.248:1521` (외부 확인 완료) |
| ARCHIVELOG | **NOARCHIVELOG** → Full Load·Schema Conversion 가능 / **CDC는 ARCHIVELOG+보충로깅 필요**(§5, bin/0140) |

## 2. 생성된 AWS 접속 계정 (공통 사용자 C##)

멀티테넌트라서 AWS 권장대로 **CDB 공통 사용자**로 생성, `CONTAINER=ALL`. PDB 서비스
(`ORCLPDB1`)로 접속해도 권한이 적용된다. 스크립트: [`01_create_dms_users.sql`](01_create_dms_users.sql)

**비밀번호는 이 저장소에 저장하지 않는다.** 규칙: **아이디(대문자) 역순**.
운영자가 실행/입력 시 직접 생성한다(예: `printf '%s' 'C##DMS' | rev`).
> 운영 환경에서는 이 역순 규칙은 약하므로 강한 시크릿 + AWS Secrets Manager 사용 권장.

| 계정 | 용도 | 비밀번호 | 비고 |
|---|---|---|---|
| `C##DMS_SC` | **DMS Schema Conversion**(메타데이터 읽기) | 아이디 역순(미저장) | CONNECT, SELECT_CATALOG_ROLE, SELECT ANY DICTIONARY |
| `C##DMS` | **DMS 데이터 마이그레이션 소스**(Full Load + CDC) | 아이디 역순(미저장) | V$/사전/SELECT ANY TABLE; CDC 는 Binary Reader 권한(03) |

> 검증 완료: 두 계정 모두 `ORCLPDB1` 접속 OK. `C##DMS` 는 SAMPLE 테이블 데이터·V$ 읽기 OK,
> `C##DMS_SC` 는 `DBA_*` 로 SAMPLE 스키마 메타데이터(15테이블/102객체/135컬럼) 읽기 OK.

## 3. AWS DMS 소스 엔드포인트 설정값

| 필드 | 값 |
|---|---|
| Endpoint type | Source |
| Engine | `oracle` |
| Server name | `<PUBLIC_IP>` (공인 IP) |
| Port | `1521` |
| Database name (Service) | **`ORCLPDB1`** (PDB 서비스명) |
| User | `C##DMS` |
| Password | 아이디 역순 규칙으로 운영자 입력(저장 안 함) |
| Secure Socket Layer | 미사용(평문) ※ 필요 시 별도 구성 |

- **SID vs Service**: 이 DB는 CDB라서 SID(`ORCL`)가 아니라 **PDB 서비스명 `ORCLPDB1`** 로 접속.
  DMS 콘솔의 "Database name" 에 `ORCLPDB1` 입력(또는 엔드포인트 설정에서 서비스명 사용).
- **멀티테넌트(CDB/PDB) 주의**: PDB 는 LogMiner 연결 불가 → CDC 는 **Binary Reader** 필수
  (`UseLogminerReader=false, UseBFile=true`; 이미 설정됨). Full Load·CDC 모두 위 설정으로 동작.
  CDC 전제조건(ARCHIVELOG·보충로깅·Binary Reader 권한)은 §5 / bin/0120·0140 로 자동화한다.

## 4. DMS Schema Conversion(또는 SCT) 설정값

| 필드 | 값 |
|---|---|
| Engine | Oracle |
| Server / Port | `<PUBLIC_IP>` / `1521` |
| Service name | `ORCLPDB1` |
| User / Password | `C##DMS_SC` / 아이디 역순 규칙(저장 안 함) |

Schema Conversion 은 데이터가 아니라 **구조(테이블/뷰/패키지/트리거/시퀀스/파티션 등)**를
읽어 PostgreSQL 로 변환한다. 이 스키마는 변환 난이도가 높은 객체(CONNECT BY 뷰, 패키지,
자율 트랜잭션 트리거, MV, 복합FK 파티셔닝 등)를 포함하므로, 변환 결과 점검 기준은
[`../../sample-data/sample-schema-bulk/MIGRATION_TEST_MATRIX.md`](../../sample-data/sample-schema-bulk/MIGRATION_TEST_MATRIX.md) 참고.

## 5. CDC(변경데이터캡처)를 쓸 경우 — ★Oracle 재시작 필요★

PDB 는 LogMiner 연결 불가 → **Binary Reader** 사용(소스 엔드포인트는 이미 `UseLogminerReader=false,
UseBFile=true`). `config.env` 에서 `MIGRATION_TYPE=full-load-and-cdc` 로 바꾼 뒤 아래 단계로 준비한다.

- **`bin/0120_grant-oracle-cdc-privileges`** → [`03_grant_binary_reader_cdc.sql`](03_grant_binary_reader_cdc.sql)
  : Binary Reader 권한(`CREATE ANY DIRECTORY`, `V_$TRANSPORTABLE_PLATFORM`, `DBMS_FILE_TRANSFER`,
  `DBMS_FILE_GROUP`, `DBA_DIRECTORIES`) + CDC 검증용 센티넬 DML 권한. 멱등.
- **`bin/0140_enable-oracle-cdc-redo`** (dry-run 기본, `--apply` 시 적용)
  : ① [`02_enable_cdc.sql`](02_enable_cdc.sql) — ARCHIVELOG 전환(`SHUTDOWN`→`MOUNT`→`ARCHIVELOG`→`OPEN`,
  **인스턴스 재시작**), NOARCHIVELOG 일 때만. ② [`04_supplemental_logging.sql`](04_supplemental_logging.sql)
  — DB-level(min+PK) + 테이블별(PK 있으면 PK, 없으면 ALL) 보충 로깅(온라인, 멱등, DBA_TABLES 도출).

> ★ ARCHIVELOG 전환 후 아카이브 redo 가 계속 쌓인다 → **FRA 여유 + 보존 ~24h** 먼저 확인
>   (`bin/0140` dry-run 이 FRA 사용량·아카이브 목적지를 함께 출력한다).
> LogMiner 권한(`DBMS_LOGMNR`,`LOGMINING`)은 남아 있어도 무해하나 Binary Reader 에선 미사용.
> Full Load(1회 이관)만 할 거면 `MIGRATION_TYPE=full-load`(기본) 이고 이 단계들은 자동 스킵된다.
> 실행/검증/컷오버: `bin/1100`(full load) → `bin/1150`(모니터) → `bin/1160`(변경 전파 검증)
> → `bin/1180 --source-quiesced`(컷오버·시퀀스 보정) → `bin/1200`(덤프).

## 6. 접속 사전 점검 (AWS EC2 등 외부에서)

```bash
# 포트 도달
nc -vz <PUBLIC_IP> 1521

# 비밀번호는 규칙(아이디 역순)으로 즉석 생성 — 어디에도 저장하지 않음
SRC_PW=$(printf '%s' 'C##DMS' | rev)        # 데이터 소스 계정
SC_PW=$(printf '%s' 'C##DMS_SC' | rev)      # 스키마 변환 계정

# 데이터 소스 계정 — 데이터/사전/V$ 읽기 확인
sqlplus C##DMS/"$SRC_PW"@<PUBLIC_IP>:1521/ORCLPDB1 <<'EOF'
SELECT COUNT(*) FROM sample.orders;
SELECT COUNT(*) FROM dba_tables WHERE owner='SAMPLE';
SELECT log_mode FROM v$database;
EOF

# 스키마 변환 계정 — 메타데이터 읽기 확인
sqlplus C##DMS_SC/"$SC_PW"@<PUBLIC_IP>:1521/ORCLPDB1 <<'EOF'
SELECT COUNT(*) FROM dba_objects WHERE owner='SAMPLE';
EOF
```

## 7. 최소 권한 옵션

`C##DMS` 에는 테스트 편의상 `SELECT ANY TABLE` 을 부여했다. 최소 권한이 필요하면
`01_create_dms_users.sql` 에서 해당 라인을 제거하고 대상 테이블만:
```sql
GRANT SELECT ON sample.<table> TO C##DMS CONTAINER=ALL;
```
로 교체한다(SAMPLE 의 15개 테이블 각각).

## 8. 재현/회수

- 계정 재생성: `sqlplus / as sysdba @migration/aws-dms/01_create_dms_users.sql` (멱등)
- 계정 회수: `DROP USER C##DMS CASCADE;  DROP USER C##DMS_SC CASCADE;` (CDB$ROOT 에서)
- 비밀번호 변경: `ALTER USER C##DMS IDENTIFIED BY "<new>" CONTAINER=ALL;`
