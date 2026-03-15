import {
  app,
  HttpRequest,
  HttpResponseInit,
  InvocationContext,
} from "@azure/functions";

const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const GITHUB_OWNER = process.env.GITHUB_OWNER;
const GITHUB_REPO = process.env.GITHUB_REPO;
const WORKFLOW_FILE = "agent-pr.yml";

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

async function uploadAgentToGitHub(
  req: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> {
  context.log("Received request: %o", req);

  const body = (await req.json()) as any;
  const { agentDefinition, deploymentName } = body;

  if (!agentDefinition || !deploymentName) {
    return {
      status: 400,
      body: "Missing agentDefinition or deploymentName in request body",
    };
  }
  context.log("agentDefinition: %o", agentDefinition);
  context.log("deploymentName: %o", deploymentName);

  const triggerResult = await triggerGitHubWorkflow({
    accountName: body.accountName,
    projectName: body.projectName,
    appName: body.appName,
    deploymentName: body.deploymentName,
    agentDefinition: body.agentDefinition,
  });
  context.log("GitHub workflow trigger result: %o", triggerResult);

  return {
    status: 200,
    body: "Workflow triggered",
  };
}

app.http("upload-agent-to-github", {
  methods: ["POST"],
  authLevel: "function",
  handler: uploadAgentToGitHub,
});
