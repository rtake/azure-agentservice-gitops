import { InvocationContext, HttpResponseInit } from "@azure/functions";
import { DefaultAzureCredential } from "@azure/identity";
import { AgentDeploymentData, fetchAgentName } from "../azure/management";
import { fetchAgentDefinition } from "../azure/agent-service";

const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const GITHUB_OWNER = process.env.GITHUB_OWNER;
const GITHUB_REPO = process.env.GITHUB_REPO;
const WORKFLOW_FILE = "agent-pr.yml";

export async function uploadAgentToGitHub(
  agentDeploymentData: AgentDeploymentData,
  context: InvocationContext,
): Promise<HttpResponseInit> {
  context.log("Received queue item: %o", agentDeploymentData);

  const credential = new DefaultAzureCredential();

  const agentName = await fetchAgentName({
    credential: credential,
    context: context,
    agentDeploymentData,
  });
  // context.log("agentName: %o", agentName);

  const agentDefinition = await fetchAgentDefinition({
    credential,
    accountName: agentDeploymentData.accountName,
    projectName: agentDeploymentData.projectName,
    agentName,
  });

  if (!agentDefinition || !agentDeploymentData.deploymentName) {
    return {
      status: 400,
      body: "Missing agentDefinition or deploymentName in request body",
    };
  }
  // context.log("agentDefinition: %o", agentDefinition);
  // context.log("deploymentName: %o", agentDeploymentData.deploymentName);

  const triggerWorkflowResult = await triggerGitHubWorkflow({
    accountName: agentDeploymentData.accountName,
    projectName: agentDeploymentData.projectName,
    appName: agentDeploymentData.appName,
    deploymentName: agentDeploymentData.deploymentName,
    agentDefinition: agentDefinition,
  });
  context.log("GitHub workflow trigger result: %o", triggerWorkflowResult);

  return {
    status: 200,
    body: "Workflow triggered",
  };
}

export async function triggerGitHubWorkflow({
  accountName,
  projectName,
  appName,
  deploymentName,
  agentDefinition,
}: {
  accountName: string;
  projectName: string;
  appName: string;
  deploymentName: string;
  agentDefinition: string;
}): Promise<Response> {
  const url = `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/workflows/${WORKFLOW_FILE}/dispatches`;

  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${GITHUB_TOKEN}`,
      Accept: "application/vnd.github+json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      ref: "main",
      inputs: {
        account_name: accountName,
        project_name: projectName,
        app_name: appName,
        deployment_name: deploymentName,
        agent_definition: JSON.stringify(agentDefinition),
      },
    }),
  });

  return res;
}
