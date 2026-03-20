import { app, InvocationContext, HttpResponseInit } from "@azure/functions";
import { AgentDeploymentData } from "../azure/management";
import { uploadAgentToGitHub } from "../github-actions/trigger-workflow";

const QUEUE_NAME = "queue-agentdeploy";
const QUEUE_CONNECTION_STRING = "QUEUE_CONNECTION_STRING";

export async function uploadAgentToGitHubFromQueue(
  agentDeploymentData: AgentDeploymentData,
  context: InvocationContext,
): Promise<HttpResponseInit> {
  const uploadResult = await uploadAgentToGitHub(agentDeploymentData, context);
  return uploadResult;
}

app.storageQueue("upload-agent-from-queue", {
  queueName: QUEUE_NAME,
  connection: QUEUE_CONNECTION_STRING,
  handler: uploadAgentToGitHubFromQueue,
});
