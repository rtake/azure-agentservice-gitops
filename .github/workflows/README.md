### エージェント定義アップロード用ワークフロー

エージェント定義をJSON形式で保存し、コミット・Push・PR作成まで実行するワークフローです。
Dev環境のAI Foundryにおけるエージェント発行をトリガーとして、Azure Functionsによって起動されます。

### エージェントデプロイ用ワークフロー

mainブランチへのマージ時にエージェントをProd環境のAI Foundryに発行するワークフローです。

#### 設定

リポジトリのSecretに以下の変数を設定してください。

| 変数名                     | 概要                                                                                                                    |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| AZURE_SUBSCRIPTION_ID      | 操作対象のAI Foundryが含まれているサブスクリプションのID                                                                |
| AIFOUNDRY_PROJECT_ENDPOINT | AI Foundryのエンドポイント (例: `https://{ai-services-account-name}.services.ai.azure.com/api/projects/{project-name}`) |
| AZURE_TENANT_ID            | GitHub Actions用のエンタープライズアプリケーションが含まれているテナントのID                                            |
| AZURE_CLIENT_ID            | GitHub Actions用のエンタープライズアプリケーションのID                                                                  |

![](/docs/github-secrets.png)
