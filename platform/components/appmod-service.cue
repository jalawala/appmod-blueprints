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
			strategy: canary: steps: [{
				setWeight: 20
			}, 
			if(parameter.functionalGate != _|_) {
				{
					pause: duration: parameter.functionGate.duration
				},
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
								value: name: "\(context.name)-preview"
							}
						]
					}
            	}
			}, {
				setWeight: 40
			}, {
				pause: duration: "10s"
			}, {
				setWeight: 80
			}, 			
			if(parameter.performanceGate != _|_) {
				{
					pause: duration: parameter.performanceGate.duration
				},
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
								value: name: "\(context.name)-preview"
							}
						]
					}
            	}
			}
            ]
			template: {
				metadata: labels: app: context.name
				spec: containers: [{
					image:           parameter.image
					imagePullPolicy: "Always"
					name:            parameter.image_name
					ports: [{
						containerPort: parameter.targetPort
					}]
				}]
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
            metadata: name: "\(context.name)-preview"
            spec: {
				selector: app: context.name
				ports: [{
					port:       parameter.port
					targetPort: parameter.targetPort
				}]
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
															"\(context.name)-preview",
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
    }

	#QualityGate: {
		image: string
		duration: string
		extraArgs: *"" | string 
	}

	parameter: {
        image_name: string
        image: string
        replicas: *3 | int
        port: *80 | int
        targetPort: *8080 | int
		functionalGate?: #QualityGate
		performanceGate?: #QualityGate
    }
}

