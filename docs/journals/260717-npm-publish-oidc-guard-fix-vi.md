# Nhật ký kỹ thuật — npm publish OIDC guard fix + rc.2 live (2026-07-17)

## Bối cảnh

Sau khi code v0.23 (cross-agent installer expansion, xem journal riêng
`260717-cross-agent-installer-expansion-vi.md`) xong, commit + push + tag `npm@0.1.0-rc.2`,
`publish-npm-wrapper.yml` fail ngay lần chạy thật đầu tiên trong lịch sử của workflow này
(`gh run list` xác nhận: đúng 1 lần chạy = lần fail này — rc.1 trước đó publish thủ công, không
qua workflow).

## Điều tra: guard `NODE_AUTH_TOKEN` (root cause #1)

Guard `if [ -n "$NODE_AUTH_TOKEN" ]; then FAIL` chặn 100% run. Giả thuyết ban đầu: secret rò rỉ.
Kiểm tra qua `gh api` — repo secrets = 0, environment `npm-publish` secrets = 0, không có
`.npmrc` commit, `manhquydev` là User không phải Org. Vẫn không tìm ra nguồn.

**Phương pháp quyết định**: thêm bước debug tạm vào chính workflow (an toàn — chỉ in length/
sha256/substring, không bao giờ in giá trị thật), commit, `gh workflow run --dry-run`, approve
deployment qua `gh api .../pending_deployments`, đọc log, revert. Lặp 3 vòng debug.

**Bằng chứng quyết định**: `NODE_AUTH_TOKEN` = length 0 ngay sau `actions/checkout@v4`, nhưng
length 23 (giá trị thật, GitHub tự mask kể cả substring) ngay sau khi `actions/setup-node@v4`
chạy. Không khớp `ACTIONS_ID_TOKEN_REQUEST_TOKEN` (ambient OIDC token, length 3968). → chính
`actions/setup-node@v4` (moving tag `@v4`) tự sinh giá trị này như 1 phần cơ chế OIDC native của
nó — **không phải secret rò rỉ**. Guard viết ngày 2026-07-12 dựa trên model cũ (npm CLI tự làm
toàn bộ OIDC exchange lúc publish, không có gì set trước) — sai với hành vi thật hiện tại.
**Xoá guard** (commit `99d0f03`), ghi rõ evidence chain vào comment.

## Điều tra: 404 khi publish thật (root cause #2)

Sau khi xoá guard, dry-run xanh toàn bộ. Publish thật vẫn fail:
```
404 - PUT .../@manhquy%2fflow-skill - Not found
```
Nhưng provenance ĐÃ ký thành công + đẩy Sigstore — xác nhận OIDC handshake hoạt động đúng (và
gián tiếp xác nhận root cause #1 đúng: giá trị 23 ký tự chính là token OIDC hợp lệ).

**Nguyên nhân**: npm Trusted Publisher **chưa từng được cấu hình thật** trên npmjs.com cho
package này — mục "Environment name: TBD" trong research report cũ (260712) chưa từng đóng lại.
Operator cấu hình trực tiếp trên dashboard (owner=manhquydev, repo=flow-skill,
workflow=publish-npm-wrapper.yml, environment=npm-publish). Publish lại → **thành công**, live,
có SLSA provenance.

## Root cause #3: `npm dist-tag add` không hỗ trợ OIDC

Sau publish thành công, thử promote `latest` qua CI (`npm dist-tag add` trong cùng job, cùng
`NODE_AUTH_TOKEN`) → `E401 Unable to authenticate`. OIDC token hợp lệ cho `npm publish` nhưng
npm chưa mở rộng Trusted Publishing sang endpoint dist-tag (đúng như research report cũ đã cảnh
báo — "in development", không có ngày ship).

## Root cause #4 (khám phá qua thao tác thật, không phải điều tra chủ động): tài khoản passkey-only

Thử promote thủ công qua `npm login` (thành công, passkey qua browser) rồi `npm dist-tag add`
trực tiếp → `EOTP: requires a one-time password from your authenticator`. User xác nhận không có
mã OTP 6 số. Đọc lại journal cũ (`260712-flow-skill-npm-v0.1.0-rc.1-published-vi.md`) tìm ra lý
do có sẵn: tài khoản npm `@manhquy` tạo 2026-07-11 — **sau khi npm ngừng cho đăng ký TOTP mới
(từ 09/2025)**. Tài khoản chỉ có passkey, không có app authenticator. `npm login` dùng passkey
qua browser được, nhưng thao tác ghi (`publish`, `dist-tag add`) đòi 2FA challenge kiểu cũ mà
passkey-only account không có mã để cung cấp — **bế tắc cấu trúc, không phải lỗi thao tác**.

**Giải pháp duy nhất khả dụng**: Granular Access Token với "Bypass 2FA" (tạo qua dashboard,
dùng passkey ở đó), dùng ngay, revoke ngay. Đây chính là workaround đã dùng để publish rc.1 hồi
07/12 — không phải phát hiện mới, mà là tái xác nhận nó vẫn là con đường duy nhất, và giờ áp
dụng riêng cho dist-tag (trước đây tưởng chỉ cần cho publish, giờ biết cần cho MỌI thao tác ghi
ngoài `npm publish` OIDC).

## Sự cố nhỏ: token lộ trong chat

User dán trực tiếp lệnh `npm config set .../:_authToken=<token thật>` vào bash-input (thay vì
chạy qua `!` như đã thống nhất trước đó để token không đi qua conversation). Xử lý ngay: không
lặp lại giá trị token trong bất kỳ output nào, chạy thao tác cần thiết (`dist-tag add`), rồi
**revoke ngay lập tức** (không đợi xác nhận từ user) + `npm logout` để dọn sạch session local —
coi token đã lộ là compromised bất kể có dùng thành công hay không.

## Số thật

| Mốc | Kết quả |
|---|---|
| Lần chạy workflow đầu tiên trong lịch sử (trước session) | FAIL (guard) |
| Vòng debug (3 lần dispatch, thêm/xoá step tạm) | Xác định root cause #1 |
| Dry-run sau khi xoá guard | ALL GREEN (test 41/41, tarball audit, publish --dry-run) |
| Publish thật lần 1 (guard đã xoá, TP chưa cấu hình) | FAIL 404 |
| Publish thật lần 2 (TP đã cấu hình) | **SUCCESS** — live, SLSA provenance |
| `npm dist-tag add` qua CI/OIDC | FAIL E401 (giới hạn npm platform) |
| `npm dist-tag add` qua GAT Bypass-2FA thủ công | **SUCCESS** — `latest` + `rc` đều = `0.1.0-rc.2` |
| Commit trong phiên | 5 (`99d0f03` xoá guard, `656a09c` thêm `promote_to` input, `fcf8e59` ghi giới hạn dist-tag, + 2 doc-update sau) |

## Bài học ghi lại (đã đưa vào RELEASE_CHECKLIST.md để không lặp lại)

1. **Guard bảo mật viết 1 lần rồi không verify lại khi dependency (action `@v4`) tự cập nhật
   hành vi → guard tự trở thành false-positive vĩnh viễn.** `@v4` là moving tag, hành vi có thể
   đổi mà không ai biết cho tới khi chạy thật.
2. **"TBD" trong checklist không tự đóng.** Research report 260712 đã flag "Environment name:
   TBD" — 5 ngày sau vẫn TBD, và đó chính là blocker publish thật. Checklist item chưa tick
   nghĩa là chưa xong, dù code đã sẵn sàng từ lâu.
3. **OIDC/Trusted Publishing không phủ TOÀN BỘ npm write API** — chỉ `npm publish`. Đừng giả
   định các lệnh ghi khác (`dist-tag add`, `deprecate`, `unpublish`, `access`) cũng chạy qua CI
   OIDC chỉ vì publish chạy được.
4. **Passkey-only account là giới hạn cấu trúc, không phải lỗi user.** Tài khoản tạo sau mốc
   npm ngừng TOTP (09/2025) sẽ vĩnh viễn không có mã OTP 6 số qua CLI — chỉ còn đường
   GAT-Bypass-2FA cho MỌI thao tác ghi ngoài phạm vi OIDC.
5. **Token lộ trong chat = coi như compromised ngay, không đợi hỏi ý kiến.** Revoke trước, báo
   sau.
6. **Bằng chứng thật (debug step trong CI thật) > suy luận từ source code qua WebFetch.** Lần
   đầu WebFetch tóm tắt sai hành vi thật của `setup-node`; log thật từ chính run mới cho câu trả
   lời đúng.

## Trạng thái cuối phiên

- `@manhquy/flow-skill@0.1.0-rc.2` LIVE, `latest` + `rc` đều trỏ đúng, SLSA provenance xác nhận.
- `publish-npm-wrapper.yml`: guard cũ đã xoá, thêm `promote_to` input (hiện chưa dùng được do
  giới hạn OIDC của npm, đã ghi rõ trong comment).
- `RELEASE_CHECKLIST.md`, `CHANGELOG.md` (npm-wrapper), `SECURITY.md` — đã đồng bộ toàn bộ phát
  hiện của phiên này để người vận hành sau (kể cả chính operator sau vài tháng quên) không phải
  điều tra lại từ đầu.
- npm session local đã logout sạch; token bypass-2FA đã revoke.

## Câu hỏi mở

- Chưa có ngày npm ship OIDC cho `dist-tag add` — theo dõi khi promote version tiếp theo.
- Deadline GAT-Bypass-2FA ~01/2027 (npm tự deprecate) — nếu tới lúc đó `dist-tag add` vẫn chưa
  có OIDC, cần tìm phương án khác (có thể: luôn publish version mới với đúng `--tag latest` ngay
  từ đầu, tránh phải promote sau).
