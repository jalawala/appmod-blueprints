"appmod-service": {
	alias: ""
	annotations: {}
	attributes: workload: definition: {
		apiVersion: "apps/v1"
		kind:       "Deployment"
	}
	description: "Appmod deployment with canary support"
	labels: {}
	type: "component"
}

template: {

    let previewService = "\(context.name)-preview"

	output: {
		apiVersion: "argoproj.io/v1alpha1"
		kind:       "Rollout"
		metadata: {
            name: context.name
        } 
		spec: {
			replicas:             parameter.replicas
			revisionHistoryLimit: 2
			selector: matchLabels: app: context.name
			strategy: canary: 
			{ 
				canaryService: previewService
				steps: [
					{
						setWeight: 20
					},
					if parameter.functionalGate != _|_ {
					{
						pause: duration: parameter.functionalGate.pause
					},
					},
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
					},
					if parameter.functionalGate != _|_ {
					{
						analysis: {
							templates: [
								{
									templateName: "functional-gate-\(context.name)"
								}
							],
							args: [
								{
									name: "service-name",
									value: previewService
								}
							]
						}
					},
					},
					{
						setWeight: 40
					},
					{
						pause: duration: "1s"
					},
					{
						setWeight: 60
					},
					{
						pause: duration: "1s"
					},
					{
						setWeight: 80
					}, 			
					if parameter.performanceGate != _|_ {
						{
							pause: {
								duration: parameter.performanceGate.pause
							}
						}
					},
					if parameter.performanceGate != _|_ {
						{
							analysis: {
								templates: [
									{
										templateName: "performance-gate-\(context.name)"
									}
								],
								args: [
									{
										name: "service-name",
										value: previewService
									}
								]
							}
						}
					}
				]
			}
			template: {
				metadata: labels: app: context.name
				spec: containers: [{
					image:           parameter.image
					imagePullPolicy: "Always"
					name:            parameter.image_name
					ports: [{
						containerPort: parameter.targetPort
					}]
					env: [{
					name:  "dummy-variable"
					value: parameter.dummyTestVariable
					}]
				}]
				spec: serviceAccountName: parameter.serviceAccount
			}
		}
	}
	outputs: {
        "appmod-service-service": {
            apiVersion: "v1"
            kind:       "Service"
            metadata: name: context.name
            spec: {
				selector: app: context.name
				ports: [{
					port:       parameter.port
					targetPort: parameter.targetPort
	            }]
            }
        },
		"appmod-service-preview": {
            apiVersion: "v1"
            kind:       "Service"
            metadata: name: previewService
            spec: {
				selector: app: context.name
				ports: [{
					port:       parameter.port
					targetPort: parameter.targetPort
				}]
            }
        }, 
		if parameter.functionalMetric != _|_ {
			"success-rate-analysis-template": {
				apiVersion: "argoproj.io/v1alpha1"
				kind:       "AnalysisTemplate"
				metadata: {
					name:      "functional-metric-\(context.name)"
				}
				spec: {
					args: [{
						name: "amp-workspace"
						valueFrom: secretKeyRef: {
							name: "workspace-url"
							key:  "secretURL"
						}
					}]
					metrics: 
					[
						for idx, criteria in parameter.functionalMetric.evaluationCriteria {
							name: "metric-\(context.name)-\(idx)"
							interval: parameter.functionalMetric.interval
							count: parameter.functionalMetric.count
							if criteria.successOrFailCondition == "success" {
								successCondition: "result[0] \(criteria.comparisonType) \(criteria.threshold)"
							}
							if criteria.successOrFailCondition == "fail" {
								failureCondition: "result[0] \(criteria.comparisonType) \(criteria.threshold)"
							}
							provider: prometheus: {
								address: "https://aps-workspaces.us-west-2.amazonaws.com/workspaces/ws-6ba7e445-e203-43a5-b1b0-c7bc15e354ef"
								query: [
									if criteria.function != _|_ {
										"\(criteria.function)(\(criteria.metric))"
									}
									if criteria.function == _|_ {
										"\(criteria.metric)"
									}
								][0]
								authentication: sigv4: region: "us-west-2"
							}
						}
					]
				}
			}
		},
		if parameter.functionalGate != _|_ {
			"appmod-functional-analysis-template": {
				kind: "AnalysisTemplate",
				apiVersion: "argoproj.io/v1alpha1",
				metadata: {
					name: "functional-gate-\(context.name)"
				},
				spec: {
					metrics: [
						{
							"name": "\(context.name)-metrics",
							"provider": {
								"job": {
									"spec": {
										"template": {
											"spec": {
												"containers": [
													{
														"name": "test",
														"image": parameter.functionalGate.image,
														"args": [
															"\(previewService):\(parameter.port)",
															"\(parameter.functionalGate.extraArgs)"
															
														]
													}
												],
												"restartPolicy": "Never"
											}
										},
										"backoffLimit": 0
									}
								}
							}
						}
					]
				}
			}
		}
        if parameter.performanceGate != _|_ {
			"appmod-performance-analysis-template": {
				kind: "AnalysisTemplate",
				apiVersion: "argoproj.io/v1alpha1",
				metadata: {
					name: "performance-gate-\(context.name)"
				},
				spec: {
					metrics: [
						{
							"name": "\(context.name)-metrics",
							"provider": {
								"job": {
									"spec": {
										"template": {
											"spec": {
												"containers": [
													{
														"name": "test",
														"image": parameter.performanceGate.image,
														"args": [
															"\(previewService):\(parameter.port)",
															"\(parameter.performanceGate.extraArgs)"
															
														]
													}
												],
												"restartPolicy": "Never"
											}
										},
										"backoffLimit": 0
									}
								}
							}
						}
					]
				}
			}
		}
    }

	#QualityGate: {
		image: string
		pause: string
		extraArgs: *"" | string 
	}

	#MetricGate: {
		interval: *"1s" | string
		count: *1 | int
		evaluationCriteria:
		[...{
				function?: "sum" | "rate" | "avg" | "max" | "min" | "increase" | "count"
				successOrFailCondition: "success" | "fail"
				metric: string
				comparisonType: ">" | ">=" | "<" | "<=" | "==" | "!="
				threshold: number
			}]
		evaluationCriteriaRatios?:
		[
			{
				successOrFailCondition: "success" | "fail"
				overallFunction?: "sum" | "rate" | "avg" | "max" | "min" | "increase" | "count"
				numeratorFunction?: "sum" | "rate" | "avg" | "max" | "min" | "increase" | "count"
				denominatorFunction?: "sum" | "rate" | "avg" | "max" | "min" | "increase" | "count"
				numeratorMetric: string
				denominatorMetric2: string
				comparisonType: ">" | ">=" | "<" | "<=" | "==" | "!="
				threshold: number
			}
		]
	}

	parameter: {
        image_name: string
        image: string
        replicas: *3 | int
        port: *80 | int
        targetPort: *8080 | int
		serviceAccount: *"default" | string
		dummyTestVariable?: string
		functionalGate?: #QualityGate
		performanceGate?: #QualityGate
		functionalMetric: #MetricGate
    }
}

