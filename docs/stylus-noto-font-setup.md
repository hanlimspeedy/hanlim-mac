# 브라우저 폰트 변경 가이드 (Stylus + Noto Sans CJK KR Bold)

## 1. Noto Sans CJK KR 폰트 설치

macOS에 Noto Sans CJK KR이 없는 경우 설치가 필요하다.

### Homebrew로 설치 (권장)

```bash
brew install --cask font-noto-sans-cjk-kr
```

### 수동 설치

1. Google Fonts에서 **Noto Sans KR** 다운로드: https://fonts.google.com/noto/specimen/Noto+Sans+KR
2. 다운로드한 폰트 파일(.otf)을 더블클릭
3. **서체 관리자**에서 **설치** 클릭

### 설치 확인

```bash
system_profiler SPFontsDataType | grep "NotoSansCJKkr"
```

7개 굵기(Thin, DemiLight, Light, Regular, Medium, Bold, Black)가 출력되면 정상이다.

## 2. Stylus 확장 프로그램 설치

1. Chrome 웹스토어에서 **Stylus** 검색 후 설치
2. Sign in 페이지가 뜨면 **무시하고 닫기** (로그인 불필요)

## 3. 새 스타일 작성

1. 브라우저 툴바에서 **Stylus 아이콘** 클릭
2. **새 스타일 작성** 클릭
3. 코드 영역에 아래 CSS 입력:

```css
@font-face {
  font-family: "ForcedFont";
  src: local("Noto Sans CJK KR Bold");
  unicode-range: U+AC00-D7AF, U+1100-11FF, U+3130-318F, U+4E00-9FFF, U+3000-303F, U+00A0-00FF, U+0100-024F, U+0020-007E;
}

*:not(i):not(span[class*="fa"]):not(span[class*="glyphicon"]):not(span[class*="sort"]):not(span[class*="chk"]) {
  font-family: "ForcedFont" !important;
}

*::before, *::after {
  font-family: inherit;
}
```

4. 스타일 이름 입력 (예: `Noto Sans Bold`)
5. **저장** 클릭

## 4. 적용 범위

- **적용 대상(Custom included sites)** 을 비워두면 모든 사이트에 자동 적용
- 특정 사이트만 적용하려면 URL 패턴 지정 가능

## 5. CSS 설명

| 구분 | 역할 |
|------|------|
| `@font-face` | Noto Sans CJK KR Bold를 ForcedFont라는 이름으로 등록. `unicode-range`로 한글/영문/CJK 문자만 대상 |
| `*:not(...)` | 아이콘 폰트 요소(FontAwesome, Glyphicon 등)를 제외한 모든 요소에 폰트 적용 |
| `*::before, *::after` | 의사 요소를 `inherit`로 설정하여 아이콘 폰트 글리프가 깨지지 않도록 보호 |

## 6. 폰트 굵기 변경

`@font-face`의 `src`에서 폰트명을 변경하면 굵기 조절 가능:

```
Noto Sans CJK KR Thin
Noto Sans CJK KR DemiLight
Noto Sans CJK KR Light
Noto Sans CJK KR          (Regular)
Noto Sans CJK KR Medium
Noto Sans CJK KR Bold
Noto Sans CJK KR Black
```

예시: `src: local("Noto Sans CJK KR Black");`

## 7. 참고

- Stylus는 브라우저 확장이므로 네이티브 앱(Outlook, 터미널 등)에는 적용 불가
- Site Font Switcher 확장은 font-weight 제어가 안 되므로 Stylus 권장
