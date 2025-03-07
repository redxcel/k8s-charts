# simple-app

Default Microservice Helm Chart

![Version: 0.1.3](https://img.shields.io/badge/Version-0.1.3-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: latest](https://img.shields.io/badge/AppVersion-latest-informational?style=flat-square)

[deployments]: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
[hpa]: https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/

This chart provides a default deployment for a simple application that operates
in a [Deployment][deployments]. The chart automatically configures various
defaults for you like the Kubernetes [Horizontal Pod Autoscaler][hpa].

## Monitoring

This chart makes the assumption that you _do_ have a Prometheus-style
monitoring endpoint configured. See the `Values.monitor.portName`,
`Values.monitor.portNumber` and `Values.monitor.path` settings for informing
the chart of where your metrics are exposed.

If you are operating in an Istio Service Mesh, see the
[Istio](#istio-networking-support) section below for details on how monitoring
works. Otherwise, see the `Values.serviceMonitor` settings to configure a
Prometheus ServiceMonitor resource to monitor your application.

## Istio Networking Support

### Monitoring through the Sidecar Proxy

[metrics_merging]: https://istio.io/latest/docs/ops/integrations/prometheus/#option-1-metrics-merging

When running your Pod within an Istio Mesh, access to the `metrics` endpoint
for your Pod can be obscured by the mesh itself which sits in front of the
metrics port and may require that all clients are coming in through the
mesh natively. The simplest way around this is to use [Istio Metrics
Merging][metrics_merging] - where the Sidecar container is responsible for
scraping your application's `metrics` port, merging the metrics with its own,
and then Prometheus is configured to pull all of the metrics from the Sidecar.

There are several advantages to this model.

* It's much simpler - developers do not need to create `ServiceMonitor` or
  `PodMonitor` resources because the Prometheus system is already configured to
  discover all `istio-proxy` sidecar containers and collect their metrics.

* Your application is not exposed outside of the service mesh to anybody - the
  `istio-proxy` sidecar handles that for you.

* There are fewer individual configurations for Prometheus, letting it's
  configuration be simpler and lighter weight. It runs fewer "scrape" jobs,
  improving its overall performance.

This feature is turned on by default if you set `Values.istio.enabled=true` and
`Values.monitor.enabled=true`.

## Secrets
A `Secret` or `KMSSecret` resource would be created and mounted into the container
based upon the `Values.secrets` and `Values.secretsEngine` being populated.
The `Secret` resource is generally used for local dev and/or CI test.
Secret` resources can be created by setting the following:
```
secrets:
  FOO_BAR: my plaintext secret
secretsEngine: plaintext
```
Alternatively, `KMSSecret` can be generated using the following example:
```
secrets:
  FOO_BAR: AQIA...
secretsEngine: kms
kmsSecretsRegion: us-west-2 (AWS region where the KMS key is located)
```

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../rxl-common | rxl-common | 0.1.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| args | list | `[]` | The arguments passed to the command. If unspecified the container defaults are used. The exact rules of how commadn and args are interpreted can be # found at: https://kubernetes.io/docs/tasks/inject-data-application/define-command-argument-container/ |
| autoscaling.behavior | `map` | `{"scaleDown":{"policies":[{"periodSeconds":60,"type":"Pods","value":5},{"periodSeconds":60,"type":"Percent","value":25}],"selectPolicy":"Min","stabilizationWindowSeconds":300},"scaleUp":{"policies":[{"periodSeconds":60,"type":"Pods","value":4},{"periodSeconds":60,"type":"Percent","value":100}],"selectPolicy":"Max","stabilizationWindowSeconds":0}}` | Controls the way that the AutoScaler scales up and down. We use this to control the speed in which the scaler responds to scaleUp and scaleDown events. Explicitly set this to `null` to let Kubernetes set its default policy. |
| autoscaling.behavior.scaleDown.policies[0] | `map` | `{"periodSeconds":60,"type":"Pods","value":5}` | Allow up to 5 pods to be removed within a 60 second window. |
| autoscaling.behavior.scaleDown.policies[1] | `map | `{"periodSeconds":60,"type":"Percent","value":25}` | On larger deployments, we want to limit the scale-down so that we don't have to bounce too quickly back up if the scale-down was too aggressive. Limit is 25% of the containers every minute. |
| autoscaling.behavior.scaleDown.selectPolicy | `string` | `"Min"` | Ensure that we can scale down up to 5 pods at a time, so that our scale-down rate is graceful in general. We'd rather scale down quickly than constantly be bouncing around.  50 -> 45 -> 40 -> 35 -> 30 -> 25 -> 20 -> 15 -> 12 -> 9 -> 7 -> 6 -> 5 -> 4 -> 3 -> 2 -> 1  |
| autoscaling.behavior.scaleDown.stabilizationWindowSeconds | `int` | `300` | https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#stabilization-window  The stabilization window is used to restrict the flapping of replica count when the metrics used for scaling keep fluctuating. The autoscaling algorithm uses this window to infer a previous desired state and avoid unwanted changes to workload scale.  For example, in the following example snippet, a stabilization window is specified for scaleDown.    behavior:     scaleDown:       stabilizationWindowSeconds: 300  When the metrics indicate that the target should be scaled down the algorithm looks into previously computed desired states, and uses the highest value from the specified interval. In the above example, all desired states from the past 5 minutes will be considered.  This approximates a rolling maximum, and avoids having the scaling algorithm frequently remove Pods only to trigger recreating an equivalent Pod just moments later.  |
| autoscaling.behavior.scaleUp.policies[0] | `map` | `{"periodSeconds":60,"type":"Pods","value":4}` | Increase by no more than 4 pods per 60 seconds.  Eg: 1 -> 5 -> 9 -> 13... |
| autoscaling.behavior.scaleUp.policies[1] | `map` | `{"periodSeconds":60,"type":"Percent","value":100}` | Increase by up to 100% of the pods per 60 seconds.  Eg: 1 -> 2 -> 4 -> 8 -> 16... |
| autoscaling.behavior.scaleUp.selectPolicy | `string` | `"Max"` | When evaluating the desired scale for the service, pick from one of the below behaviors based on which one scales up the most pods.  So, when scaling from 1 pod, the pattern looks like this:  1 -> 5 -> 10 -> 20 -> 40 -> 80  (over 5 minutes)  |
| autoscaling.behavior.scaleUp.stabilizationWindowSeconds | `int` | `0` | https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#stabilization-window  The stabilization window is used to restrict the flapping of replica count when the metrics used for scaling keep fluctuating. The autoscaling algorithm uses this window to infer a previous desired state and avoid unwanted changes to workload scale.  For example, in the following example snippet, a stabilization window is specified for scaleDown.    behavior:     scaleDown:       stabilizationWindowSeconds: 300  When the metrics indicate that the target should be scaled down the algorithm looks into previously computed desired states, and uses the highest value from the specified interval. In the above example, all desired states from the past 5 minutes will be considered.  This approximates a rolling maximum, and avoids having the scaling algorithm frequently remove Pods only to trigger recreating an equivalent Pod just moments later.  |
| autoscaling.enabled | bool | `false` | Controls whether or not an HorizontalPodAutoscaler resource is created. |
| autoscaling.maxReplicas | int | `100` | Sets the maximum number of Pods to run |
| autoscaling.minReplicas | int | `1` | Sets the minimum number of Pods to run |
| autoscaling.targetCPUUtilizationPercentage | int | `80` | Configures the HPA to target a particular CPU utilization percentage |
| command | list | `[]` | The command run by the container. This overrides `ENTRYPOINT`. If not specified, the container's default entrypoint is used. The exact rules of how commadn and args are interpreted can be # found at: https://kubernetes.io/docs/tasks/inject-data-application/define-command-argument-container/ |
| containerName | string | `""` |  |
| deploymentStrategy | object | `{}` | https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy |
| deploymentZones | `string[]` | `[]` | If supplied, an individual `Deployment` (and optional `HPA`) is created for each of the Availability Zone strings passed in. The default usage of this parameter would be to ensure that each AZ in your infrastructure has its own Deployment and HPA for scaling that is independent of the others. This is useful for services that are accessed by zone-aware clients, where the load may be imbalanced from one zone to another. |
| deploymentZonesTransition | `bool` | `false` | During the transition from (or to) individual zone deployment resources, flip this setting to `True` to enable the creation of BOTH the Zone-Aware AND Default Deployment resources. This ensures that during the rollover from one to the other configuration, you do not lose all of your pods. |
| enablePodDisruptionBudget | bool | `true` | Set up a PodDisruptionBudget for the Deployment. See https://kubernetes.io/docs/tasks/run-application/configure-pdb/ for more details. |
| enableTopologySpread | `bool` | `false` | If set to `true`, then a default `TopologySpreadConstraint` will be created that forces your pods to be evenly distributed across nodes based on the `topologyKey` setting. The maximum skew between the spread is controlled with `topologySkew`. |
| env | list | `[]` | Environment Variables for the primary container. These are all run through the tpl function (the key name and value), so you can dynamically name resources as you need. |
| envFrom | list | `[]` | Pull all of the environment variables listed in a ConfigMap into the Pod. See https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/#configure-all-key-value-pairs-in-a-configmap-as-container-environment-variables for more details. |
| extraContainers | list | `[]` |  |
| fullnameOverride | string | `""` |  |
| image.forceTag | String | `nil` | Forcefully overrides the `image.tag` setting - this is useful if you have an outside too that automatically updates the `image.tag` value, but you want your application operators to be able to squash that override themselves. |
| image.pullPolicy | String | `"IfNotPresent"` | Always, Never or IfNotPresent |
| image.repository | String | `"nginx"` | The Docker image name and repository for your application |
| image.tag | String | `nil` | Overrides the image tag whose default is the chart appVersion. |
| imagePullSecrets | list | `[]` | Supply a reference to a Secret that can be used by Kubernetes to pull down the Docker image. This is only used in local development, in combination with our `kube_create_ecr_creds` function from dotfiles. |
| ingress.annotations | object | `{}` | Any annotations you wish to add to the ALB. See https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/guide/ingress/annotations/ for more details. |
| ingress.enabled | bool | `false` |  |
| ingress.host | string | `"{{ include \"rxl-common.fullname\" . }}.{{ .Release.Namespace }}"` | This setting configures the ALB to listen specifically to requests for this hostname. It _also_ ties into the external-dns controller and automatically provisions DNS hostnames matching this value (presuming that they are allowed by the cluster settings). |
| ingress.path | string | `"/"` | See the `ingress.pathType` setting documentation. |
| ingress.pathType | string | `"Prefix"` | https://kubernetes.io/docs/concepts/services-networking/ingress/#path-types |
| ingress.port | string | `nil` | If set, this will override the `service.portName` parameter, and the `Service` object will point specifically to this port number on the backing Pods. |
| ingress.portName | string | `"http"` | This is the port "name" that the `Service` will point to on the backing Pods. This value must match one of the values of `.name` in the `Values.ports` configuration. |
| ingress.sslRedirect | bool | `true` | If `true`, then this will annotate the Ingress with a special AWS ALB Ingress Controller annotation that configures an SSL-redirect at the ALB level. |
| initContainers | list | `[]` |  |
| istio.enabled | `bool` | `false` | Whether or not the service should be part of an Istio Service Mesh. If this is turned on and `Values.monitor.enabled=true`, then the Istio Sidecar containers will be configured to pull and merge the metrics from the application, rather than creating a new `PodMonitor` object. |
| istio.excludeInboundPorts | `int[]` | `[]` | If supplied, this is a list of TCP ports that are excluded from being proxied by the Istio-proxy Envoy sidecar process. _The `.Values.monitor.portNumber` is already included by default. |
| istio.metricsMerging | `bool` | `false` | If set to "True", then the Istio Metrics Merging system will be turned on and Envoy will attempt to scrape metrics from the application pod and merge them with its own. This defaults to False beacuse in most environments we want to explicitly split up the metrics and collect Istio metrics separate from Application metrics. |
| istio.preStopCommand | `list <str>` | `nil` | If supplied, this is the command that will be passed into the `istio-proxy` sidecar container as a pre-stop function. This is used to delay the shutdown of the istio-proxy sidecar in some way or another. Our own default behavior is applied if this value is not set - which is that the sidecar will wait until it does not see the application container listening on any TCP ports, and then it will shut down.  eg: preStopCommand: [ /bin/sleep, "30" ] |
| kmsSecretsRegion | String | `nil` | AWS region where the KMS key is located |
| livenessProbe | string | `nil` | A PodSpec container "livenessProbe" configuration object. |
| minReadySeconds | string | `nil` | https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#min-ready-seconds |
| monitor.annotations | `map` | `{}` | PodMonitor annotations. |
| monitor.enabled | `bool` | `false` | If enabled, PodMonitor resources for Prometheus Operator are created or if `Values.istio.enabled` is `True`, then the appropriate Pod Annotations will be added for the istio-proxy sidecar container to scrape the metrics. |
| monitor.interval | string | `nil` | PodMonitor scrape interval |
| monitor.labels | object | `{}` | Additional PodMonitor labels. |
| monitor.metricRelabelings | list | `[]` | PodMonitor MetricRelabelConfigs to apply to samples before ingestion. https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md#relabelconfig |
| monitor.path | `string` | `"/metrics"` | Path to scrape metrics from within your Pod. |
| monitor.portName | `string` | `"metrics"` | Name of the port to scrape for metrics - this is the name of the port that will be exposed in your `PodSpec` for scraping purposes. |
| monitor.portNumber | `int` | `9090` | Number of the port to scrape for metrics - this port will be exposed in your `PodSpec` to ensure it can be scraped. |
| monitor.relabelings | list | `[]` | PodMonitor relabel configs to apply to samples before scraping https://github.com/prometheus-operator/prometheus-operator/blob/master/Documentation/api.md#relabelconfig |
| monitor.sampleLimit | `int` | `25000` | The maximum number of metrics that can be scraped - if there are more than this, then scraping will fail entirely by Prometheus. This is used as a circuit breaker to avoid blowing up Prometheus memory footprints. |
| monitor.scheme | `enum: http, https` | `"http"` | PodMonitor will use http by default, but you can pick https as well |
| monitor.scrapeTimeout | string | `nil` | PodMonitor scrape timeout in Go duration format (e.g. 15s) |
| monitor.tlsConfig | string | `nil` | PodMonitor will use these tlsConfig settings to make the health check requests |
| nameOverride | string | `""` |  |
| network.allowedNamespaces | `strings[]` | `[]` | A list of namespaces that are allowed to access the Pods in this application. If not supplied, then no `NetworkPolicy` is created, and your application may be isolated to itself. Note, enabling `VirtualService` or `Ingress` configurations will create their own dedicated `NetworkPolicy` resources, so this is only intended for internal service-to-service communication grants. |
| nodeSelector | `map` | `{}` | A list of key/value pairs that will be added in to the nodeSelector spec for the pods. |
| podAnnotations | `Map` | `{}` | List of Annotations to be added to the PodSpec |
| podDisruptionBudget.maxUnavailable | int | `1` |  |
| podLabels | `Map` | `{}` | List of Labels to be added to the PodSpec |
| podSecurityContext | object | `{}` |  |
| ports | `ContainerPort[]` | `[{"containerPort":80,"name":"http","port":null,"protocol":"TCP"}]` | A list of Port objects that are exposed by the service. These ports are applied to the main container. The port list is also used to generate Network Policies that allow ingress into the pods. See https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.21/#containerport-v1-core for details. **Note: We have added an optional "port" field to this list that allows the user to override the Service Port (for example 80) that a client  connects to, without altering the Container Port (say, 8080) that is listening for connections. |
| preStopCommand | list | `["/bin/sleep","10"]` | Before a pod gets terminated, Kubernetes sends a SIGTERM signal to every container and waits for period of time (10s by default) for all containers to exit gracefully. If your app doesn't handle the SIGTERM signal or if it doesn't exit within the grace period, Kubernetes will kill the container and any inflight requests that your app is processing will fail.  Make sure you set this to SHORTER than the terminationGracePeriod (30s default) setting.  https://docs.flagger.app/tutorials/zero-downtime-deployments#graceful-shutdown |
| progressDeadlineSeconds | string | `nil` | https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#progress-deadline-seconds |
| prometheusRules.CPUThrottlingHigh | object | `{"for":"15m","severity":"warning","threshold":5}` | Container is being throttled by the CGroup - needs more resources. This value is appropriate for applications that are highly sensitive to request latency. Insensitive workloads might need to raise this percentage to avoid alert noise. |
| prometheusRules.ContainerWaiting | object | `{"for":"1h","severity":"warning"}` | Pod container waiting longer than threshold |
| prometheusRules.DeploymentGenerationMismatch | object | `{"for":"15m","severity":"warning"}` | Deployment generation mismatch due to possible roll-back |
| prometheusRules.DeploymentReplicasMismatch | object | `{"for":"15m","severity":"warning"}` | Deployment has not matched the expected number of replicas |
| prometheusRules.HpaMaxedOut | object | `{"for":"15m","severity":"warning"}` | HPA is running at max replicas |
| prometheusRules.HpaReplicasMismatch | object | `{"for":"15m","severity":"warning"}` | HPA has not matched descired number of replicas |
| prometheusRules.PodContainerTerminated | object | `{"for":"1m","over":"10m","reasons":["ContainerCannotRun","DeadlineExceeded"],"severity":"warning","threshold":0}` | Monitors Pods for Containers that are terminated either for unexpected reasons like ContainerCannotRun. If that number breaches the $threshold (1) for $for (1m), then it will alert. |
| prometheusRules.PodCrashLoopBackOff | object | `{"for":"10m","severity":"warning"}` | Pod is in a CrashLoopBackOff state and is not becoming healthy. |
| prometheusRules.PodNotReady | object | `{"for":"15m","severity":"warning"}` | Pod has been in a non-ready state for more than a specific threshold |
| prometheusRules.additionalRuleLabels | `map` | `{}` | Additional custom labels attached to every PrometheusRule |
| prometheusRules.enabled | `bool` | `false` | Whether or not to enable the prometheus-alerts chart. |
| readinessProbe | string | `nil` | A PodSpec container "readinessProbe" configuration object. |
| replicaCount | `int` | `2` | The number of Pods to start up by default. If the `autoscaling.enabled` parameter is set, then this serves as the "start scale" for an application. Setting this to `null` prevents the setting from being applied at all in the PodSpec, leaving it to Kubernetes to use the default value (1). https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#replicas |
| resources | object | `{}` |  |
| revisionHistoryLimit | `int` | `3` | The default revisionHistoryLimit in Kubernetes is 10 - which is just really noisy. Set our default to 3. https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#clean-up-policy |
| runbookUrl | string | `"https://github.com/redxcel/k8s-charts/blob/main/charts/simple-app/README.md"` | The URL of the runbook for this service. |
| secrets | `Map` | `{}` | Map of environment variables to plaintext secrets or KMS encrypted secrets. |
| secretsEngine | String | `"plaintext"` | Secrets Engine determines the type of Secret Resource that will be created (`KMSSecret`, `Secret`). kms || plaintext are possible values. |
| securityContext | object | `{}` |  |
| service.name | `string` | `nil` | Optional override for the Service name. Can be used to create a simpler more friendly service name that is not specific to the application name. |
| service.type | string | `"ClusterIP"` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `""` |  |
| startupProbe | string | `nil` | A PodSpec container "startupProbe" configuration object. |
| targetArchitecture | `string` | `"amd64"` | If set, this value will be used in the .spec.nodeSelector to ensure that these pods specifically launch on the desired target host architecture. If set to null/empty-string, then this value will not be set. |
| targetOperatingSystem | `string` | `"linux"` | If set, this value will be used in the .spec.nodeSelector to ensure that these pods specifically launch on the desired target Operating System. Must be set. |
| terminationGracePeriodSeconds | string | `nil` | https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/#hook-handler-execution |
| tests.connection.args | list | `["{{ include \"rxl-common.fullname\" . }}"]` | A list of arguments passed into the command. These are run through the tpl function. |
| tests.connection.command | list | `["curl","--retry-connrefused","--retry","5"]` | The command used to trigger the test. |
| tests.connection.image.repository | string | `"curlimages/curl"` | Sets the image-name that will be used in the "connection" integration test. If this is left empty, then the .image.repository value will be used instead (and the .image.tag will also be used). By default, prefer the latest official version to handle cases where the app image provides either no curl binary or an outdated one. |
| tests.connection.image.tag | string | `nil` | Sets the tag that will be used in the "connection" integration test. If this is left empty, the default is "latest" |
| tolerations | list | `[]` |  |
| topologyKey | `string` | `"topology.kubernetes.io/zone"` | The topologyKey to use when asking Kubernetes to schedule the pods in a particular distribution. The default is to spread across zones evenly. Other options could be `kubernetes.io/hostname` to spread across EC2 instances, or `node.kubernetes.io/instance-type` to spread across instance types for example. |
| topologySkew | `int` | `1` | The maxSkew setting applied to the default TopologySpreadConstraint if `enableTopologySpread` is set to `true`. |
| topologySpreadConstraints | `string` | `[]` | An array of custom TopologySpreadConstraint settings applied to the PodSpec within the Deployment. Each of these TopologySpreadObjects should conform to the [`pod.spec.topologySpreadConstraints`](https://kubernetes.io/docs/concepts/workloads/pods/pod-topology-spread-constraints/#api) API - but the `labelSelector` field should be left out, it will be inserted automatically for you. |
| virtualService.annotations | object | `{}` | Any annotations you wish to add to the `VirtualService` resource. See https://istio.io/latest/docs/reference/config/annotations/ for more details. |
| virtualService.corsPolicy | `map` | `{}` | If set, this will populate the corsPolicy setting for the VirtualService. See https://istio.io/latest/docs/reference/config/networking/virtual-service/#CorsPolicy for more details. |
| virtualService.enabled | Boolean | `false` | Maps the Service to an Istio IngressGateway, exposing the service outside of the Kubernetes cluster. |
| virtualService.gateways | list | `[]` | The name of the Istio `Gateway` resource that this `VirtualService` will register with. You can get a list of the avaialable `Gateways` by running `kubectl -n istio-system get gateways`. Not specifying a Gateway means that you are creating a VirtualService routing definition only inside of the Kubernetes cluster, which is totally reasonable if you want to do that. |
| virtualService.hosts | list | `["{{ include \"rxl-common.fullname\" . }}"]` | A list of destination hostnames that this VirtualService will accept traffic for. Multiple names can be listed here. See https://istio.io/latest/docs/reference/config/networking/virtual-service/#VirtualService for more details. |
| virtualService.matches | `map[]` | `{}` | A list of Istio `HTTPMatchRequest` objects that will be applied to the VirtualService. This is the more advanced and customizable way of controlling which paths get sent to your backend. These are added _in addition_ to the `paths` or `path` settings. See https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPMatchRequest for examples. |
| virtualService.namespace | string | `"istio-system"` | The namespace where the Istio services are operating. Do not change this. |
| virtualService.path | string | `"/"` | The default path prefix that the `VirtualService` will match requests against to pass to the default `Service` object in this deployment. |
| virtualService.paths | `string[]` | `[]` | List of optional path prefixes that the `VirtualService` will use to match requests against and will pass to the `Service` object in this deployment. This list replaces the `path` prefix above - use one or the other, do not use both. |
| virtualService.port | int | `80` | This is the backing Pod port _number_ to route traffic to. This must match a `containerPort` in the `Values.ports` list. |
| virtualService.retries | `map` | `{}` | Pass in an optional [`HTTPRetry`](https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPRetry) configuration here to control how services retry their failed requests to the backend service. The default behavior is to retry 2 times if a 503 is returned. |
| virtualService.tls | string | `""` |  |
| volumeMounts | list | `[]` | List of VolumeMounts that are applied to the application container - these must refer to volumes set in the `Values.volumes` parameter. |
| volumes | list | `[]` | A list of 'volumes' that can be mounted into the Pod. See https://kubernetes.io/docs/concepts/storage/volumes/. |
| volumesString | string | `""` | A stringified list of 'volumes' similar to the `Values.volumes` parameter, but this one gets run through the `tpl` function so that you can use templatized values if you need to. See https://kubernetes.io/docs/concepts/storage/volumes/. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
