# BabyCare server (VPS Oracle)

Hạ tầng backend tự host, thay Supabase cloud. Kế hoạch: `../BACKEND_VPS_PLAN.md`.

- Máy: Ubuntu 22.04 ARM64 (Ampere, 4 nhân, 23 GB RAM), `ubuntu@158.178.232.52`, thư mục triển khai `/srv/babycare`.
- Giai đoạn 0: `sudo bash scripts/bootstrap.sh` (cập nhật, Docker, swap, tắt nginx mặc định), rồi `cp .env.example .env && docker compose up -d`.
- Kiểm tra: `curl https://158-178-232-52.sslip.io/healthz` trả `ok`.

## Sao lưu và khôi phục

- Mỗi đêm 02:30 giờ Việt Nam, `scripts/backup.sh` (cron `/etc/cron.d/babycare-backup`, do `deploy.sh` cài) ghi vào `/srv/babycare/backups`:
  - `db-<ngày>.dump`: `pg_dump` dạng custom;
  - `files-<ngày>/`: bản chụp thư mục ảnh, ảnh không đổi dùng chung hard link nên không tốn thêm chỗ.
- Giữ 14 bản mới nhất. Nhật ký: `journalctl -t babycare-backup`; đĩa dùng từ 80% trở lên thì có dòng `WARNING`.
- Bản sao nằm cùng đĩa với dữ liệu: cứu được khi xoá nhầm, không cứu được khi mất cả máy. Cần chép thêm ra ngoài VPS (Object Storage) trước khi có nhiều người dùng.
- Log của Docker giới hạn 5 file × 10 MB mỗi dịch vụ (`x-logging` trong `docker-compose.yml`).

Khôi phục database từ một bản dump (API ngừng trong lúc đó):

```bash
cd /srv/babycare
sudo docker compose stop api
sudo docker compose exec -T db pg_restore -U postgres -d babycare --clean --if-exists < backups/db-<ngày>.dump
sudo rsync -a --delete backups/files-<ngày>/ files/
sudo docker compose start api
```

## Tài khoản tạo tay (App Review)

`server/scripts/create-user.sh AppStore/review-account.local.txt` (chạy trên Mac) đọc hai dòng `Email:` và `Password:`, rồi tạo tài khoản email **đã xác nhận** trên VPS, không cần gửi thư. Nếu tài khoản đã có thì chỉ đổi mật khẩu, giữ nguyên dữ liệu. Không truyền đối số thì script hỏi email và mật khẩu. Mật khẩu đi qua stdin của SSH, không hiện trong lệnh hay log (`src/admin/createUser.ts` chạy trong container `api`).
