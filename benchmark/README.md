# Hikari Benchmark

このディレクトリには、Hikariのパフォーマンスを測定するためのベンチマークアプリケーションが含まれています。

## 実行環境 (Reference Environment)

ベンチマークは以下の環境で実行された結果に基づいています。

- CPU: Intel(R) Xeon(R) Processor @ 2.30GHz (4 cores)
- RAM: 7.8Gi
- OS: Linux
- ツール: `bombardier`

## ベンチマークの実行方法

1. **`bombardier` のインストール**

   ```bash
   go install github.com/codesenberg/bombardier@latest
   ```
   ※ `$GOPATH/bin` にパスを通してください。

2. **自動ベンチマークの実行**

   リポジトリに含まれる `run.sh` スクリプトを使用して、Hikari、Go Fiber、Hono (Bun) の3つのフレームワークに対するベンチマークテストを自動的にコンパイル・実行・比較できます。

   ```bash
   cd benchmark
   ./run.sh
   ```

   スクリプトは以下の3エンドポイントを各フレームワークに対して計測します：

   | エンドポイント | 内容 |
   |---|---|
   | `/` | JSON レスポンス（フレームワーク基準比較） |
   | `/text` | プレーンテキスト（最小オーバーヘッド計測） |
   | `/users/:id` | パスパラメータ（ルーター性能計測） |

3. **個別の負荷テストの実行**

   Hikariの単体テストを行う場合は、以下のようにビルドして `bombardier` を実行します。

   ```bash
   v -prod benchmark/main.v -o /tmp/hikari_bench
   /tmp/hikari_bench &
   bombardier -c 100 -n 100000 http://localhost:3000/
   ```

## パフォーマンスの比較

単一エンドポイントに対するJSONレスポンスのテストでは、**Hono (with Bun) の約3.6倍のパフォーマンス**、**Go Fiberと同等の速度**を叩き出しています。

*100コネクション, 100,000リクエスト, `bombardier`を使用（Intel Xeon 2.30GHz, 4 cores, 7.8Gi RAM）*

| Framework | Language | Reqs/sec (Avg) | Latency (Avg) | Throughput |
| :--- | :--- | :--- | :--- | :--- |
| **Hikari** | **VLang** | **84,097 req/s** | **1.18 ms** | 17.35 MB/s |
| Go Fiber | Go | 89,331 req/s | 1.14 ms | 19.14 MB/s |
| Hono | TypeScript (Bun) | 22,862 req/s | 4.38 ms | 5.15 MB/s |
