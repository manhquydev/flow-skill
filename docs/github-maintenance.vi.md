# Sử dụng GitHub để phát triển Flow

## Vòng làm việc hằng ngày

1. Tạo branch từ `master` mới nhất, ví dụ `fix/installer-path`.
2. Thay đổi nhỏ, chạy kiểm tra theo [AGENTS.md](../AGENTS.md), rồi push branch.
3. Mở Pull Request (PR) vào `master`, mô tả lý do, kết quả và bằng chứng kiểm tra.
4. Xem tab Files changed và Checks, xử lý trao đổi còn mở.
5. Chỉ merge khi `all-checks-passed` xanh. Có thể chọn Squash and merge để gom commit của PR, hoặc bật auto-merge cho PR đó để chờ CI.

Quy tắc `Protect master` yêu cầu PR, kiểm tra `all-checks-passed` từ GitHub Actions và giải quyết trao đổi review; chặn force-push và xóa nhánh chính. Số approval bắt buộc là 0 để một người duy trì vẫn tự merge được. Không có bypass. Muốn điều chỉnh, vào Settings → Rules → Rulesets. Không push trực tiếp vào `master`.

CI đa hệ điều hành có thể mất thời gian, đặc biệt trên Windows. Xem [workflow CI](../.github/workflows/ci.yml) để biết các job; chạy lại khi có lỗi hạ tầng, sửa code khi kiểm tra thực sự thất bại. Không tắt quy tắc chỉ để vượt qua CI đỏ.

## Đọc tab Security and quality

- **Dependabot alerts:** dependency nào có lỗ hổng, mức độ và phiên bản sửa. Ưu tiên critical/high; đọc tác động thực tế và kiểm tra PR sửa lỗi.
- **Dependabot security updates:** tự mở PR khi có bản vá phù hợp. Đã bật gom security updates theo hệ sinh thái/thư mục. PR vẫn cần kiểm tra trước khi merge.
- **Code scanning / CodeQL:** đã cấu hình default setup cho JavaScript/TypeScript, Python và GitHub Actions. Xem đường đi dữ liệu và vị trí cảnh báo; kiểm tra rồi sửa qua PR. CodeQL không quét được mọi lỗi trong Bash và không thay thế các bash suites. Cấu hình quét không đồng nghĩa đã quét thành công; xem kết quả lần chạy đầu trong Actions.
- **Secret scanning:** cảnh báo credential mà GitHub nhận diện. Nếu là secret thật, thu hồi/rotate tại nhà cung cấp trước, rồi xử lý code và lịch sử theo tình huống. Chỉ xóa dòng code chưa vô hiệu hóa secret đã lộ.
- **Push protection:** chặn push chứa secret được hỗ trợ. Không bypass một secret thật; dùng secret store phù hợp. Fixture giả cần kiểm tra kỹ trước khi đánh dấu false positive.
- **Private vulnerability reporting:** người dùng báo lỗi kín qua [Report a vulnerability](https://github.com/manhquydev/flow-skill/security/advisories/new). Quy trình và phạm vi hỗ trợ ở [SECURITY.md](../SECURITY.md).

CodeQL hiện là công cụ phát hiện; quy tắc merge bắt buộc hiện tại là `all-checks-passed`, chưa bắt buộc kết quả CodeQL. Chỉ bổ sung CodeQL làm điều kiện merge khi đã xác minh quét ổn định.

## Cập nhật dependency

Cấu hình gốc là [dependabot.yml](../.github/dependabot.yml): kiểm tra npm installer và GitHub Actions lúc 09:00 thứ Hai, múi giờ Asia/Bangkok. Minor/patch được gom theo từng nhóm; major tách riêng để xem thay đổi không tương thích. Tối đa 3 PR cập nhật phiên bản đang mở cho mỗi mục cấu hình; PR bảo mật có giới hạn riêng của GitHub. Cấu hình chỉ bắt đầu hoạt động sau khi vào nhánh mặc định.

Xem changelog của dependency, diff lockfile và CI trước khi merge. Với npm installer, tham khảo kiểm tra trong AGENTS.md. Không bật merge tự động hàng loạt cho mọi PR của bot.

`website/` chưa được thêm vào lịch cập nhật phiên bản: CONTRIBUTING.md dành nó cho `feat/flow-website`, nhưng nhánh đó không tồn tại trên remote lúc thiết lập. Cần thống nhất chính sách branch trước khi thêm mục `/website`. Dependency graph và cảnh báo bảo mật vẫn bao phủ manifest được GitHub nhận diện trên nhánh mặc định; PR bảo mật chạm website cần được kiểm tra theo chính sách đó.

## Quản lý công việc và phát hành

Dùng **Issues** cho bug/tính năng cụ thể với mẫu sẵn có. Một issue nên có kết quả mong đợi và tiêu chí hoàn thành; PR có thể dùng `Closes #123` để đóng issue khi merge. Báo lỗ hổng theo SECURITY.md.

Dùng **Milestones** khi đã có phạm vi một phiên bản rõ ràng. Khi backlog lớn, dùng **Projects** với Todo / In progress / Done, liên kết issue và PR; tránh tạo thêm hệ thống trùng thông tin đã có trong Flow.

Phát hành theo [release-process.md](release-process.md). Skill và npm installer có hai phiên bản riêng. Không dùng PR Dependabot để tự bump phiên bản sản phẩm. Chưa bật thêm AI Scan, agentic autofix hoặc tự yêu cầu Copilot review trong lần thiết lập này.

## Kiểm tra mỗi tuần

Xử lý cảnh báo bảo mật và PR Dependabot; xem Actions thất bại; rà issue cần phản hồi. Với cảnh báo bị dismiss, ghi lý do có thể kiểm chứng. Kiểm tra kết quả quét thay vì chỉ nhìn trạng thái Enabled.

Tài liệu GitHub: [CodeQL default setup](https://docs.github.com/en/code-security/how-tos/find-and-fix-code-vulnerabilities/configure-code-scanning/configure-code-scanning), [Dependabot version updates](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/configuring-dependabot-version-updates).
