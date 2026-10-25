#!/bin/bash
# Q8：repair 时识别并停止采集器、修复 HTTP 服务；cleanup 时停止修复后的服务。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

action=${3:-repair}

# TODO：删除下方提示和 exit 77，再填写你的命令。
mkdir -p "$output/service"
if [ "$action" = repair ]; then
    source "$input/process.env"
    actual_pid=$( ps -o pid= -p "$TARGET_PID" | xargs)
    actual_user=$(ps -o user= -p "$TARGET_PID")
    actual_state=$(ps -o state= -p "$TARGET_PID")
    actual_command=$(ps -o command= -p "$TARGET_PID")
    printf 'pid=%s\nuser=%s\nstate=%s\ncommand=%s\n' "$actual_pid" "$actual_user" "$actual_state" "$actual_command" > "$output/process.txt"
    grep "TICK" "$WORKER_LOG" | tail -3 > "$output/collector-sample.log"
    kill "$TARGET_PID"
    for i in $(seq 1 12); do
    kill -0 "$TARGET_PID" 2>/dev/null || break
    if ps -o stat= -p "$TARGET_PID" | grep -q "^Z"; then break; fi
    sleep 0.2
    done
    kill "$SERVICE_PID"
    for i in $(seq 1 12); do
    kill -0 "$SERVICE_PID" 2>/dev/null || break
    if ps -o stat= -p "$SERVICE_PID" | grep -q "^Z"; then break; fi
    sleep 0.2
    done
    printf 'bind=127.0.0.1\nport=%s\nroute=/status\n' "$TARGET_PORT" > "$output/server.conf"
    bash "$START_TOOL" "$output/server.conf" "$output/service"
    url="http://127.0.0.1:$TARGET_PORT/status"
    for i in $(seq 1 8); do
    if curl -s -m 2 "$url" > "$output/http-body.txt" 2>/dev/null; then break; fi
    sleep 0.5
    done
    curl -s -o /dev/null -w '%{http_code}\n' "$url" > "$output/http-status.txt"
elif [ "$action" = cleanup ]; then
    source "$input/process.env"
    svc=$(cat "$output/service/pid")
    kill "$svc"
    for i in $(seq 1 12); do
    kill -0 "$svc" 2>/dev/null || break
    if ps -o stat= -p "$svc" | grep -q "^Z"; then break; fi
    sleep 0.2
    done
    for i in $(seq 1 50); do
    if ! ss -ltn | grep -q ":$TARGET_PORT "; then break; fi
    sleep 0.2
    done
fi
