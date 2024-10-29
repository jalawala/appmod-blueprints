# Application Specification

The following configuration specifies an application that includes a Rust-based backend. It requires a DynamoDB table and a service account, with `ComponentDefinitions` provided separately.

The main focus here is on configuring the `appmod-service` component, which leverages the solution setup when the application is ready. Below are the necessary fields to complete for a successful setup:

- **name**: `rust-backend` - Assign a name to your application.
- **type**: `appmod-service` - Designate this as the appmod solution.
- **properties**: Contains values required to set up Argo Rollouts properly.
  - `image`: `891612574912.dkr.ecr.us-west-2.amazonaws.com/modernengg/rust-microservice:latest` - Path to the container image running the application.
  - `image_name`: `rust-microservice` - Name of the targeted image.
  - `port`: `80` - The port for the application.
  - `targetPort`: `8080` - The application's target port.
  - `replicas`: `5` - The number of replicas for the rollout.
  - `serviceAccount`: `"rust-service-account"` - Service account name for the specified workload.
  - `dummyTestVariable`: `"test-#"` - Optional variable for testing. Modifying this value counts as a change, triggering a rollout.
  - **functionalMetric** (Optional): 
    - `interval`: `"1s"` - Specify interval with suffix `s`, `m`, or `h`.
    - `count`: `1`
    - **evaluationCriteria**: Define an array of metrics to be tested.
      - `function`: `"sum"` - Optional. Choose a metric tracking augmentation function from `"sum"`, `"rate"`, `"avg"`, `"max"`, `"min"`, `"increase"`, `"count"`.
      - `successOrFailCondition`: `"success"` - Determines if the metric should pass or fail. Options are `"success"` or `"fail"`.
      - `metric`: `"rocket_http_requests_total"` - The case-sensitive name of the metric to track.
      - `comparisonType`: `">"` - Choose a comparison operator from `">"`, `">="`, `"<"`, `"<="`, `"=="`, `"!="`.
      - `threshold`: `0` - Specify a numeric threshold.

---

# Technical Details of the CUE Configuration

### Parameter Setup

The parameter `functionalMetric` of type `#MetricGate` is added for metric configuration.

```cue
parameter:
  functionalMetric: #MetricGate

#MetricGate: {
  interval: *"1s" | string
  count: *1 | int
  evaluationCriteria: [
    ...{
      function?: "sum" | "rate" | "avg" | "max" | "min" | "increase" | "count" # These are some of the most popular options for functions.
      successOrFailCondition: "success" | "fail" # Two options of pass or fail.
      metric: string 
      comparisonType: ">" | ">=" | "<" | "<=" | "==" | "!="
      threshold: number # Can be a whole number or decimal.
    }
  ]
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
# Implementation of Metrics

The following CUE code snippet creates an `AnalysisTemplate` for monitoring functional metrics in Argo Rollouts. This template defines metrics-based criteria that determine the success or failure of rollouts.

## Analysis Template Code

```cue
if parameter.functionalMetric != _|_ {
    "success-rate-analysis-template": {
        apiVersion: "argoproj.io/v1alpha1"
        kind:       "AnalysisTemplate"
        metadata: {
            name:      "functional-metric-\(context.name)"
        }
        spec: {
            args: [{
                name: "amp-workspace" # Calls the needed amp-workspace url from the secret amp-workspace.
                valueFrom: secretKeyRef: {
                    name: "workspace-url"
                    key:  "secretURL"
                }
            }]
            metrics: 
            [
                for idx, criteria in parameter.functionalMetric.evaluationCriteria { # Loops through all the metrics the user specifies in the array.
                    name: "metric-\(context.name)-\(idx)"
                    interval: parameter.functionalMetric.interval
                    count: parameter.functionalMetric.count
                    if criteria.successOrFailCondition == "success" { # Handles successCondition variables.
                        successCondition: "result[0] \(criteria.comparisonType) \(criteria.threshold)"
                    }
                    if criteria.successOrFailCondition == "fail" { # Handles failureCondition variables.
                        failureCondition: "result[0] \(criteria.comparisonType) \(criteria.threshold)"
                    }
                    provider: prometheus: {
                        address: "https://aps-workspaces.us-west-2.amazonaws.com/workspaces/ws-6ba7e445-e203-43a5-b1b0-c7bc15e354ef" # Having trouble making this work like YAML's {{args.amp-workspace}} so hard coded for now.
                        query: [
                            if criteria.function != _|_ { # Handles the optional addition of a function added to the front of a query.
                                "\(criteria.function)(\(criteria.metric))"
                            }
                            if criteria.function == _|_ { # Handles if no function is specified.
                                "\(criteria.metric)"
                            }
                        ][0] # The [0] uses the if statement that is true.
                        authentication: sigv4: region: "us-west-2" # Hanldes authentication with Amazon Managed Prometheus.
                    }
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
                image: 891612574912.dkr.ecr.us-west-2.amazonaws.com/modernengg/rust-microservice:latest
                image_name: rust-microservice
                port: 80
                targetPort: 8080
                replicas: 5
                serviceAccount: "rust-service-account"
                dummyTestVariable: "test-67"
                functionalMetric:
                interval: "1s" # Add time unit: s, m, or h.
                count: 1
                evaluationCriteria: [
                    {
                    function: "sum",
                    successOrFailCondition: "success",
                    metric: "rocket_http_requests_total",
                    comparisonType: ">",
                    threshold: 0
                    },
                    {
                    successOrFailCondition: "success",
                    metric: "rocket_http_requests_total",
                    comparisonType: ">",
                    threshold: 0
                    },
                    {
                    successOrFailCondition: "success",
                    metric: "rocket_http_requests_total",
                    comparisonType: ">",
                    threshold: 0
                    },
                    {
                    successOrFailCondition: "success",
                    metric: "rocket_http_requests_total",
                    comparisonType: ">",
                    threshold: 0
                    },
                    {
                    successOrFailCondition: "success",
                    metric: "rocket_http_requests_total",
                    comparisonType: ">",
                    threshold: 0
                    }
                ]
                # Uncomment these sections for additional gates
                # functionalGate:
                #   pause: "10s"
                #   image: "public.ecr.aws/i8e1q7x5/appmod-javafunctest:latest"
                #   extraArgs: "red"
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
