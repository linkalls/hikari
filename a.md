了解しました — 先に「残っている子プロセス」を消してから設定を反映したい、という意図ですね。安全にできる手順を示します。実行したい場合は教えてください（実行するかどうか確認してからコマンドを走らせます）。

やること（短く）
- 1) 現在の worker プロセスを一覧で確認する
- 2) 必要ならそれらをまとまて TERM → KILL で止める
- 3) ランタイムが使う PID ファイルを削除してクリーンにする
- 4) そのあとでサーバ（master）を再起動して新設定を反映

安全確認用コマンド（まず一覧を確認してください）
```bash
# 実行中の hikari/example/main プロセスを一覧表示
pgrep -af '/home/poteto/hikari/example/main'
# または ps で確認（あなたが貼った出力と同じ）
ps aux | grep '/home/poteto/hikari/example/main' | grep -v grep
# children.pids の中身確認
[ -f logs/children.pids ] && cat logs/children.pids || echo "logs/children.pids not found"
```

止める（安全な順序で TERM → 少し待って生き残りがあれば KILL）
```bash
# 全 worker プロセスへ SIGTERM を送る（優しく終了を促す）
pgrep -f '/home/poteto/hikari/example/main' | xargs -r kill -TERM

# 5秒待ってまだ残っているプロセスがあれば強制終了
sleep 5
pgrep -f '/home/poteto/hikari/example/main' | xargs -r kill -KILL
```

PID ファイルを削除（クリーンアップ）
```bash
rm -f logs/children.pids
```

その後の確認と再起動
```bash
# 正常に停止したか確認
pgrep -af '/home/poteto/hikari/example/main' || echo "no workers running"

# 再起動（あなたが普段使うコマンドで）
v run example/main.v
# もしくはビルドして実行する場合
v -prod -o bin/hikari_server example/main.v
./bin/hikari_server
```

やって良いですか？
- 私に代わりにコマンドを実行してほしいなら「実行して」と一言ください（その場合、先に一覧を表示して確認してから TERM→KILL→削除を実行します）。
- 自分で実行する場合は、まず一覧コマンドを実行して出力を貼ってください。必要に応じて安全な個別 PID 指定で止め方を案内します。