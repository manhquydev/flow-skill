# Ship readiness — skill 0.31.0 / npm 0.7.1-next.0

2026-08-21. master `c075927`. Không publish, không bump.

## latest vs next

| Kênh | npm | Skill |
|---|---|---|
| `@latest` | **0.7.0** | v0.30.0 |
| `@next` | **0.7.1-next.0** | v0.31.0 |

Live `npm view` khớp. README cũng ghi vậy. Nightly registry health xanh hôm nay trên HEAD.

## Có đưa `@next` lên `@latest` không?

**Không — đừng `dist-tag add` bản `-next.0` lên latest.**

Nội dung 0.31.0 sẵn sàng bán. Kênh đang bán thì không nên trỏ prerelease. Cắt đúng nghĩa: installer **0.7.1** (bỏ preid), tag `npm@0.7.1`, workflow gắn `latest`. OIDC không làm được `dist-tag add` (E401).

CI không chặn: PR #15 (release) và #16 (HEAD) `all-checks-passed` + bash-suite 3-OS xanh. Publish `npm@0.7.1-next.0` xanh.

## Chặn gì

- **Chặn kênh:** `@latest` đang 0.7.0. Muốn 0.31.0 ra cửa `npx @latest` thì phải cắt **0.7.1** ổn định, không promote `-next.0`.
- **Không chặn:** DEBT macOS timeout. Guard refuse-by-default đã nằm trên `@latest` từ 0.30.0. 0.31.0 giữ `_run_with_timeout` y nguyên (eval STOP). Mechanism chưa đóng — đóng trước khi coi fallback là bound, hoặc trước khi gỡ guard. Không phải điều kiện cắt hàng.

## Việc tiếp theo

1. Cắt `0.7.1` ổn định, tag `npm@0.7.1`, approve `npm-publish`.
2. Sau publish: `npm view` dist-tags + `npx @manhquy/flow-skill@latest --help` in skill v0.31.0; sửa bảng version README.
3. macOS: giữ refuse-guard; `scripts/macos-timeout-watchdog-diag.sh` khi muốn đóng DEBT — không chặn bước 1.
