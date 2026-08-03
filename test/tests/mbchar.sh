#!/bin/sh
DUMP=mongodump
OUT_DIR=/data/backup/mongod/tmp   // 备份文件临时目录
TAR_DIR=/data/backup/mongod       // 备份文件将压缩正式目录
DATE=`date +%Y_%m_%d_%H_%M_%S`    // 备份文件将会加备份时间保存
DB_USER=Guitang                   // 数据库操作员
DB_PASS=qq                        // 数据库操作员密码
DAYS=14                           // 保留最近14天的备份
TAR_BAK="mongod_bak_$DATE.tar.gz" // 备份文件存档名称格式
cd $OUT_DIR                       // 进入临时目录
rm -rf $OUT_DIR/*                 // 清空临时文件
mkdir -p $OUT_DIR/$DATE           // 为备份文件存放目录创建文件夹
$DUMP -d wecard -u $DB_USER -p $DB_PASS -o $OUT_DIR/$DATE   // 执行备份命令
tar -zcvf $TAR_DIR/$TAR_BAK $OUT_DIR/$DATE       // 将备份文件打包成正式包
find $TAR_DIR/ -mtime +$DAYS -delete             // 删除14天前的旧备份
