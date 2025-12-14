#!/bin/bash
set -e

# 自动初始化配置文件（如果不存在）
if [ ! -f "/app/config/config.yaml" ]; then
    echo "📋 未检测到 config.yaml，使用默认配置..."
    cp /app/config.default/config.yaml /app/config/config.yaml
fi

if [ ! -f "/app/config/frequency_words.txt" ]; then
    echo "📋 未检测到 frequency_words.txt，使用默认配置..."
    cp /app/config.default/frequency_words.txt /app/config/frequency_words.txt
fi

echo "✅ 配置文件就绪"

# 保存环境变量
env >> /etc/environment

case "${RUN_MODE:-cron}" in
"once")
    echo "🔄 单次执行"
    exec /usr/local/bin/python main.py
    ;;
"cron")
    # 生成 crontab
    echo "${CRON_SCHEDULE:-*/30 * * * *} cd /app && /usr/local/bin/python main.py" > /tmp/crontab
    
    echo "📅 生成的crontab内容:"
    cat /tmp/crontab

    if ! /usr/local/bin/supercronic -test /tmp/crontab; then
        echo "❌ crontab格式验证失败"
        exit 1
    fi

    # 立即执行一次（如果配置了）
    if [ "${IMMEDIATE_RUN:-false}" = "true" ]; then
        echo "▶️ 立即执行一次"
        /usr/local/bin/python main.py
    fi

    # 启动 Web 服务器（如果配置了）
    if [ "${ENABLE_WEBSERVER:-false}" = "true" ]; then
        echo "🌐 启动 Web 服务器..."
        /usr/local/bin/python manage.py start_webserver
    fi

    echo "⏰ 启动supercronic: ${CRON_SCHEDULE:-*/30 * * * *}"
    echo "🎯 supercronic 将作为 PID 1 运行"

    exec /usr/local/bin/supercronic -passthrough-logs /tmp/crontab
    ;;
*)
    exec "$@"
    ;;
esac