# azurefunctions-githubworkflow

## 概要

本リポジトリは、Azure AI Foundry Agent Serviceにおけるエージェント発行をトリガーに、エージェント定義をGitHubに自動エクスポートし、Pull Requestを作成するイベント駆動パイプラインの実装例を提供します。

本番環境の安定稼働を目的としてAI Foundryを開発環境と本番環境で分離して運用する場合、開発したエージェントを本番環境へ反映するプロセスが必要になります。しかし、手作業によるエクスポートと反映では、変更履歴の追跡やレビュー・承認プロセスの担保が難しいという課題があります。

本パイプラインでは、開発環境でのエージェント発行を Activity Logから検知し、エージェント定義の取得・GitHub へのコミット・Pull Requestの作成までを自動化します。さらに、Pull Requestのマージをトリガーとして本番環境へエージェントを発行するワークフローを組み込むことで、変更のレビューを挟んだGitOpsベースの運用フローが実現できます。

## システム構成

![](/docs/system-architecture.png)

- Azure Monitor - アクティビティログを監視しエージェントの管理操作を検知しアクショングループに設定したAzure Functionsをトリガーします
- Azure Functions (parse log) - エージェント発行イベントの場合にエージェントの情報をアクティビティログのログエントリーからパースし、Queueに格納します
- Queue storage
-

## デプロイ・セットアップ

### 前提

- Azureのサブスクリプションが作成されていること
- Azure CLIがインストールされていること
- GitHub上にリポジトリが作成されていること

### Azure

リソースグループ作成後、`az deployment` コマンドでリソースを作成します。

```
# リソースグループ作成
az group create --name <ResourceGroupName> -l <RegionName>

# Dry-run
az deployment group what-if -g <ResourceGroupName> -p infra/param.bicepparam

# リソース作成
cd azure/
az deployment group create --resource-group <ResourceGroupName> --template-file infra/main.bicep  -p infra/param.bicepparam
または
az deployment group create -g <ResourceGroupName> -p infra/param.bicepparam # パラメータファイルの中で main.bicepを参照している場合
```

#### Azure Functions

リソース作成後、Azure Functionsをビルドしデプロイします。

```
cd azure/functions
npm i
npm run build # ビルド
func azure functionapp publish <FunctionAppName> # デプロイ
```

環境変数に以下の値を設定します。

| 変数 | 説明 |
| ---- | ---- |
|      |      |

#### アラート設定

アラートのアクショングループにデプロイした関数を追加します。
リソースグループの中のアクショングループの編集画面に進み、アクションに「detect-agent-publish」を追加します。

![](/docs/action-group.png)

#### テスト

`detect-agent-publish` を起動することでパイプラインの挙動をテストすることができます。
.envにURLとキーを記載し, シェルスクリプトを実行します。
GitHub上でワークフローが起動し、PR作成が確認できたら成功です。

```
cd azure/functions/test-scripts/upload-agent-to-github
bash trigger.sh
```

## 設計上のポイント
