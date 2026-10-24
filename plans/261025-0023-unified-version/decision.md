# Quyết định owner: thống nhất một version chung (skill + npm)

- **Thời điểm:** 00:23 Asia/Bangkok, 25/10/2026.
- **Người có thẩm quyền:** owner (qua controller). Đây là bản ghi quyền quyết, không phải đề xuất.
- **Bogtek cũ bị supersede:** quy ước "hai trục version tách biệt, npm ≠ skill, không bump chung"
  (docs/release-process.md bản trước, sync-release check #5, release-preflight warning) không còn hiệu lực
  cho các release sau quyết định này.

## Quyết định

1. Skill product và npm installer dùng **một SemVer chung**, đồng bộ từ đây về sau. Một thay đổi
   chỉ installer hay chỉ skill vẫn là **một release version chung**.
2. Giữ nguyên tên trường tương thích (`npm_version`, `skill_version`, `expected_version`, banner
   `flow-skill vX (ships skill vY)`, `portable-manifest`, marketplace catalog) — không xoá surface;
   giá trị hai trục bằng nhau và được machine-guard kiểm tra bằng nhau.
3. **Không đụng lịch sử đã phát hành:** tag `v1.0.0` (794fd02) và `npm@0.8.0` giữ nguyên, không
   retag/move/đổi nghĩa. Các bản 0.7.13/0.7.14 giữ hold như cũ.

## Mục tiêu alignment đầu tiên: **1.0.0 chung** (npm 0.8.0 → 1.0.0)

Căn cứ số học, không phải ước muốn:

- Tag `v1.0.0` đã tồn tại, trỏ `794fd026141e23a29b5c79af072e7f4fd0bdc165`, **bất động**.
- Tree hash của `skills/` tại `794fd02` và tại PR89 head `7d4d4b883fc40e3fd9f69443528840339871f5d6`:
  - `604639b76e7ba3d7a41019c484f4c4c864c47967` == `60439b7…` (**giống từng byte**; `git diff --stat -- skills/` rỗng).
- PR89 chỉ đổi tests/docs/config, không đổi skill content → npm 1.0.0 bundle skill **cùng nội dung**
  với tag `v1.0.0`. Không cần waiver/digest-exception: skill axis đã được tag đúng version với đúng nội dung.
- Nếu sau này `skills/` đổi so với tag hiện hành cùng số version → ship **phải từ chối** và buộc
  bump chung tiếp theo (1.0.1/…), không được relabel nội dung khác thành version cũ.

## Cơ chế một version (machine-owned authority)

- `npm-wrapper/package.json` `version` là **bản sao phát hành**; `skills/flow/SKILL.md` `version:` là
  **nguồn chuẩn chung**. `sync-release --sync` sinh/cập nhật mirror; `--check` bắt drift.
- Guards đổi theo: sync-release check #5 thành "Unified version (npm_v === skill_v)";
  release-preflight bỏ warning "equals — usually accidental"; skill tag đã tồn tại chỉ được chấp nhận
  khi subtree digest `skills/` của tag == subtree của HEAD, nếu không fail-closed.
- Publisher giữ đúng interface hiện có (`expected_version` = version chung); eligibility check
  `intent.npm_version == package version` và `intent.skill_version == bundled skill version` — hai
  trường giữ tên, giá trị bắt buộc bằng nhau.
- Nhãn chung là KẾT QUẢ của readiness, không phải mục tiêu thẩm mỹ: acceptance v1 đã được
  disposition ACHIEVED 7/7 tại 794fd02 (plans/261023-1233-omp-v1-readiness/v1-disposition-261025.md).

## Phạm vi thi hành (lane UNIFY-VERSION, sau PR89)

- `scripts/sync-release.mjs`, `scripts/release-preflight.sh`, `scripts/release-workflow.mjs` (nếu cần),
  `docs/release-intent.json` (release kế: 1.0.0/1.0.0, latest), README/release-process/CHANGELOG
  (npm-wrapper ## 1.0.0), tests coherence/sync-release, i18n pairs cho mọi docs đổi.
- Sequence: PR89 merge trước (đỡ xung đột docs/tests), rồi unify PR tái cơ sở master mới, CI exact-head,
  review độc lập, merge, publish qua `scripts/release.sh` với latch+gates như 0.8.0.
- Giữ nguyên: Eval STOP, root WIP, holds cũ, fail-closed provenance/CI/review gates.
