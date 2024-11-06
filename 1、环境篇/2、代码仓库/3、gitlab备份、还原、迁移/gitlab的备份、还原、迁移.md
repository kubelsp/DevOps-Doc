### gitlab的备份、还原、迁移

**1、Gitlab（容灾备份）**

方式1：本地目录

```shell
docker exec -t gitlab gitlab-backup create
```

方式2：对象存储

```shell
# 把 gitlab 备份上传到 minio 上的 gitlab 桶上

docker run --rm -it --entrypoint=/bin/sh -v ~/gitlab/data/backups:/data minio/mc -c "
mc config host add minio http://192.168.1.10:9000 xyL2RgM3dkCjkS6WfRzD CzcpzWbV82YUImM4Go2V3bKSOsY3sfVfkquvg1JD
mc cp -r /data/ minio/gitlab"

docker run --rm -it --entrypoint=/bin/sh -v ~/gitlab/config/gitlab.rb:/data/gitlab.rb minio/mc -c "
mc config host add minio http://192.168.1.10:9000 xyL2RgM3dkCjkS6WfRzD CzcpzWbV82YUImM4Go2V3bKSOsY3sfVfkquvg1JD
mc cp /data/gitlab.rb minio/gitlab/gitlab.rb-$(date +%Y-%m-%d_%H:%M:%S)"

docker run --rm -it --entrypoint=/bin/sh -v ~/gitlab/config/gitlab-secrets.json:/data/gitlab-secrets.json minio/mc -c "
mc config host add minio http://192.168.1.10:9000 xyL2RgM3dkCjkS6WfRzD CzcpzWbV82YUImM4Go2V3bKSOsY3sfVfkquvg1JD
mc cp /data/gitlab-secrets.json minio/gitlab/gitlab-secrets.json-$(date +%Y-%m-%d_%H:%M:%S)"
```

**2、Gitlab（还原、迁移）**

```shell
docker exec -it gitlab /bin/bash
```

```shell
gitlab-ctl status

gitlab-ctl stop puma

gitlab-ctl stop sidekiq
```

```shell
ll /var/opt/gitlab/backups/
```

```shell
chmod 777 *gitlab_backup.tar
```

```shell
gitlab-backup restore BACKUP=1713691705_2024_04_21_16.11.0
```

```shell
gitlab-ctl status

gitlab-ctl start
```

