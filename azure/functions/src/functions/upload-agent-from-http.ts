import {
  app,
  HttpRequest,
  HttpResponseInit,
  InvocationContext,
} from "@azure/functions";
import { uploadAgentToGitHubFromQueue } from "./upload-agent-from-queue";

async function uploadAgentToGitHub(
  req: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> {
  const { agentDeploymentData: agentDeploymentData } = req.json() as any;
  const uploadResult = await uploadAgentToGitHubFromQueue(
    agentDeploymentData,
    context,
  );
  return uploadResult;
}

app.http("upload-agent-from-http", {
  methods: ["POST"],
  authLevel: "function",
  handler: uploadAgentToGitHub,
});
