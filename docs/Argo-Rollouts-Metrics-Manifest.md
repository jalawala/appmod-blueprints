### Things still in the works:
- Need to modify image example for load testing to return a success rather than fail when it finishes load testing.
- Do no currently have a functional test image for the sample application.

# Technical Details of the CUE Parameter Configuration

### Parameter Setup

The parameter `functionalMetric` of type `#MetricGate` are added for metric configuration.

```cue
parameter:
  functionalMetric?: #MetricGate

#MetricGate: {
    evaluationCriteria:
    [...{
            interval: *"1s" | string
            count: *1 | int
            function?: "sum" | "avg" | "max" | "min" | "count"
            successOrFailCondition: *"success" | "fail" # Two options of pass or fail.
            metric: string
            comparisonType: *">" | ">=" | "<" | "<=" | "==" | "!="
            threshold: *0 | number # Can be a whole number or decimal.
        }]
}
```

### Creates Analysis Template
```cue
if parameter.functionalMetric !=  _|_ {
{
    analysis: {
        templates: [
            {
                templateName: "functional-metric-\(context.name)"
            }
        ],
        args: [
            {
                name: "service-name"
                value: previewService
            }
        ]
    }
}
}
```

# Sample Application Configuration for Rust App with Argo Rollouts and DynamoDB

The following configuration defines a Rust-based application that requires a DynamoDB table, a service account, and a backend service component configured with Argo Rollouts. 

## Application Overview

```YAML
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: rust-app
spec:
  components:
    - name: dynamodb-table
      type: dynamodb-table
      properties:
        tableName: rust-service-table
        partitionKeyName: partition_key
        sortKeyName: sort_key 
        region: us-west-2
      traits:
        - type: component-iam-policy
          properties:
            service: dynamodb
    - name: rust-service-account
      type: dp-service-account
      properties:
        componentNamesForAccess:
          - dynamodb-table
        clusterName: modernengg-dev
        clusterRegion: us-west-2
        dependsOn:
          - dynamodb-table
    - name: rust-backend
      type: appmod-service
      properties:
        image:  891612574912.dkr.ecr.us-west-2.amazonaws.com/modernengg/rust-microservice:latest
        image_name: rust-microservice
        port: 80
        targetPort: 8080
        replicas: 5
        serviceAccount: "rust-service-account"
        dummyTestVariable: "test-1"
        functionalMetric:
          evaluationCriteria: [
            {
              interval: "1s", # user needs to add s, m, or h next to the number.
              count: 1,
              function: "sum",
              successOrFailCondition: "success",
              metric: "rocket_http_requests_total",
              comparisonType: ">",
              threshold: 0
            },
            {
              interval: "1s", # user needs to add s, m, or h next to the number.
              successOrFailCondition: "success",
              function: "avg",
              metric: "rocket_http_requests_duration_seconds_sum",
              comparisonType: ">",
              threshold: 0
            },
            {
              interval: "1s", # user needs to add s, m, or h next to the number.
              count: 1,
              successOrFailCondition: "success",
              function: "max",
              metric: "rocket_http_requests_duration_seconds_count",
              comparisonType: ">",
              threshold: 0
            },
            {
              interval: "1s", # user needs to add s, m, or h next to the number.
              count: 1,
              function: "count",
              successOrFailCondition: "success",
              metric: "rocket_http_requests_duration_seconds_bucket",
              comparisonType: ">",
              threshold: 0
            },
            {
              interval: "1s", # user needs to add s, m, or h next to the number.
              count: 1,
              successOrFailCondition: "fail",
              metric: "rocket_http_requests_total",
              comparisonType: "<",
              threshold: 0
            }

          ]
        #functionalGate:
        #  pause: "10s" 
        #  image: "public.ecr.aws/i8e1q7x5/appmod-javafunctest:latest"
        #  extraArgs: "red"
        # performanceGate:
        #   pause: "10s"
        #   image: "public.ecr.aws/i8e1q7x5/javaperftest:latest"
        #   extraArgs: "160"
      dependsOn:
        - rust-service-account
      traits: 
        - type: path-based-ingress
          properties:
            domain: "*.elb.us-west-2.amazonaws.com"
            rewritePath: true 
            http:
              /rust-app: 80
```
## Sample Application Breakdown

The following configuration specifies an application that includes a Rust-based backend. It requires a DynamoDB table and a service account, with `ComponentDefinitions` provided separately.

The main focus here is on configuring the `appmod-service` component, which leverages the solution setup when the application is ready. Below are the necessary fields to complete for a successful setup:

- **name**: `rust-backend` - Assign a name to your application.
- **type**: `appmod-service` - Designate this as the appmod solution.
- **properties**: Contains values required to set up Argo Rollouts properly.
  - `image`: `891612574912.dkr.ecr.us-west-2.amazonaws.com/modernengg/rust-microservice:latest` - Path to the container image running the application.
  - `image_name`: `rust-microservice` - Names the container it runs on.
  - `port`: `80` - The port for the application.
  - `targetPort`: `8080` - The application's target port.
  - `replicas`: `5` - The number of replicas for the rollout.
  - `serviceAccount`: `"rust-service-account"` - Service account name for the specified workload.
  - `dummyTestVariable`: `"test-#"` - Optional variable for testing. Modifying this value counts as a change, triggering a rollout.
  - **functionalMetric** (Optional): 
    - **evaluationCriteria**: Define an array of metrics to be tested. Each metric in the array specify the following values:
      - `interval`: `"1s"` - Specify interval with suffix `s`, `m`, or `h`.
      - `count`: `1`
      - `function`: `"sum"` - Optional. Choose a metric tracking augmentation function from `"sum"`, `"avg"`, `"max"`, `"min"`, `"count"`.
      - `successOrFailCondition`: `"success"` - Determines if the metric should pass or fail. Options are `"success"` or `"fail"`.
      - `metric`: `"rocket_http_requests_total"` - The case-sensitive name of the metric to track.
      - `comparisonType`: `">"` - Choose a comparison operator from `">"`, `">="`, `"<"`, `"<="`, `"=="`, `"!="`.
      - `threshold`: `0` - Specify a numeric threshold.

---
# Troubleshooting User Scenarios

If the given metric does not exist or returns nothing, you should expect an error in the **Rollout**:

- **Strategy:** Canary  
- **Name:** rust-backend  
- **Namespace:** test-123  
- **Status:** ✖ Degraded  
- **Message:** `RolloutAborted: Rollout aborted update to revision 16: Metric "metric[0]-rust-backend: rocket_http_reqsdfadfuests_total" assessed Error due to consecutiveErrors (5) > consecutiveErrorLimit (4): "Error Message: reflect: slice index out of range"`

---

If a metric fails the test/condition the user sets up, the first failure hit returns this in **Rollouts**:

- **Strategy:** Canary  
- **Name:** rust-backend  
- **Namespace:** test-123  
- **Status:** ✖ Degraded  
- **Message:** `RolloutAborted: Rollout aborted update to revision 13: Metric "metric[2]-rust-backend: rocket_http_requests_total" assessed Failed due to failed (1) > failureLimit (0)`

---

If `evaluationCriteria[]` values are of the wrong type specified that the CUE Manifest requires when they deploy their application, they get this as an **Application Message**:

- **Message:** `run step(provider=oam,do=component-apply): GenerateComponentManifest: evaluate base template app=rust-app in namespace=test-123: invalid cue template of workload rust-backend after merge parameter and context: parameter.functionalMetric.evaluationCriteria.0.count: 2 errors in empty disjunction: (and 5 more errors)`

---

While default values work fine if they don't put a value in for one that has a default set up, if a user did not enter a required variable that lacks a default (like `metrics` inside of `evaluationCriteria`, for example), expect the following as an **Application Message**:

- **Message:** `run step(provider=oam,do=component-apply): GenerateComponentManifest: evaluate template trait=path-based-ingress app=rust-backend: cue: marshal error: outputs."success-rate-analysis-template".spec.metrics.1.name: invalid interpolation: non-concrete value string (type string)`


