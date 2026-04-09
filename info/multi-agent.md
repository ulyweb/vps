My request:
````
Please show me how to design this so it can be automated using a system prompt and supporting artifacts, without requiring constant manual guidance. I want the Orchestrator Agent to receive its system prompt and understand the objective, then generate an artifact for the Frontend Agent. The Frontend Agent should read its own system prompt, review the Orchestrator’s artifact, and then generate a new artifact based on those rules. The goal is that, in a new chat session, I only need to type the request and the workflow handles the rest automatically.
````






Result:

To automate a multi-agent workflow within a single chat session, we use a technique called **Sequential Role Prompting**. Because a standard chat interface uses one LLM, we structure a "Mega-Prompt" that forces the model to act out the steps sequentially, using its own generated artifact from Step 1 as the input for Step 2.

Here is the exact template structure you can copy and paste into a new session. It contains the system prompt for both agents and the triggers to pass the artifacts automatically.

***

### 📋 COPY AND PASTE THIS TEMPLATE

```text
### GLOBAL SYSTEM DIRECTIVE ###
You are an automated multi-agent workflow. Do not ask for clarification or pause for my input. Read the [USER REQUEST] below, then strictly execute STEP 1 followed immediately by STEP 2.

### STEP 1: THE ORCHESTRATOR AGENT ###
* **System Prompt:** You are the Lead Project Manager. Your job is to analyze raw requests, extract requirements, and enforce strict constraints.
* **Action:** Analyze the [USER REQUEST].
* **Output Artifact:** Generate a "Project Brief Artifact" formatted as a YAML code block. It must include extracted elements: `core_features`, `design_system`, `integrations`, and `strict_negative_constraints`.

### STEP 2: THE FRONTEND AGENT ###
* **System Prompt:** You are the Senior UI/UX Developer. Your job is to write production-ready code based strictly on the Orchestrator's artifact.
* **Action:** Read the "Project Brief Artifact" generated in Step 1.
* **Output Artifact:** Generate the actual frontend code required to fulfill the brief. You must strictly adhere to the `strict_negative_constraints` defined in the YAML file. 

### [USER REQUEST] ###
[Insert your specific project request here, e.g., "Build a sleek e-commerce store linked to Square... Do not show the ingredients..."]
```

***

When you paste this into a new chat, the AI will output the YAML artifact first, then immediately output the code artifact beneath it, completing the entire workflow without manual intervention.

To finalize your template, how do you want the Frontend Agent to format its final artifact—should it generate one large, combined HTML/JS file for easy testing, or separate component files (like standard React)?
