import * as cdk from "aws-cdk-lib";
import * as eks from "aws-cdk-lib/aws-eks";
import * as iam from "aws-cdk-lib/aws-iam";
import { Construct } from "constructs";
import { AddOnStackProps } from "../interface/addon-props";

export class OtelAddOnStack extends Construct {
  constructor(scope: Construct, id: string, props: AddOnStackProps) {
    super(scope, id);

    const otelNamespaceName = "otel-system";
    const otelServiceAccountName = "aws-otel-sa";

    const cluster = props.cluster;

    const otelNamespace = cluster.addManifest("my-otel-namespace", {
      apiVersion: "v1",
      kind: "Namespace",
      metadata: { name: otelNamespaceName },
    });

    const sa = cluster.addServiceAccount("my-otel-svc-account", {
      name: otelServiceAccountName,
      namespace: otelNamespaceName,
    });

    const otelDaemonAccess = iam.ManagedPolicy.fromAwsManagedPolicyName(
      "CloudWatchAgentServerPolicy"
    );
    sa.role.addManagedPolicy(otelDaemonAccess);
    sa.node.addDependency(otelNamespace);

    const otelRole = cluster.addManifest("my-cluster-role", {
      kind: "ClusterRole",
      apiVersion: "rbac.authorization.k8s.io/v1",
      metadata: {
        name: "aoc-agent-role",
      },
      rules: [
        {
          apiGroups: [""],
          resources: ["pods", "nodes", "endpoints"],
          verbs: ["list", "watch", "get"],
        },
        {
          apiGroups: ["apps"],
          resources: ["replicasets"],
          verbs: ["list", "watch", "get"],
        },
        {
          apiGroups: ["batch"],
          resources: ["jobs"],
          verbs: ["list", "watch"],
        },
        {
          apiGroups: [""],
          resources: ["nodes/proxy"],
          verbs: ["get"],
        },
        {
          apiGroups: [""],
          resources: ["nodes/stats", "configmaps", "events"],
          verbs: ["create", "get"],
        },
        {
          apiGroups: [""],
          resources: ["configmaps"],
          verbs: ["update"],
        },
        {
          apiGroups: [""],
          resources: ["configmaps"],
          resourceNames: ["otel-container-insight-clusterleader"],
          verbs: ["get", "update", "create"],
        },
        {
          apiGroups: ["coordination.k8s.io"],
          resources: ["leases"],
          verbs: ["create", "get", "update"],
        },
        {
          apiGroups: ["coordination.k8s.io"],
          resources: ["leases"],
          resourceNames: ["otel-container-insight-clusterleader"],
          verbs: ["get", "update", "create"],
        },
      ],
    });

    const otelRoleBinding = cluster.addManifest("my-otel-role-binding", {
      kind: "ClusterRoleBinding",
      apiVersion: "rbac.authorization.k8s.io/v1",
      metadata: {
        name: "aoc-agent-role-binding",
      },
      subjects: [
        {
          kind: "ServiceAccount",
          name: otelServiceAccountName,
          namespace: otelNamespaceName,
        },
      ],
      roleRef: {
        kind: "ClusterRole",
        name: "aoc-agent-role",
        apiGroup: "rbac.authorization.k8s.io",
      },
    });

    otelRoleBinding.node.addDependency(otelRole);
    otelRoleBinding.node.addDependency(otelNamespace);

    const otelConfigMap = cluster.addManifest("my-otel-configmap", {
      apiVersion: "v1",
      kind: "ConfigMap",
      metadata: {
        name: "otel-agent-conf",
        namespace: otelNamespaceName,
        labels: {
          app: "opentelemetry",
          component: "otel-agent-conf",
        },
      },
      data: {
        "otel-agent-config": `extensions:
  health_check:

receivers:
  awscontainerinsightreceiver:

processors:
  batch/metrics:
    timeout: 60s

exporters:
  awsemf:
    namespace: ContainerInsights
    log_group_name: '/aws/containerinsights/{ClusterName}/performance'
    log_stream_name: '{NodeName}'
    resource_to_telemetry_conversion:
      enabled: true
    dimension_rollup_option: NoDimensionRollup
    parse_json_encoded_attr_values: [Sources, kubernetes]
    metric_declarations:
      # node metrics
      - dimensions: [[NodeName, InstanceId, ClusterName]]
        metric_name_selectors:
          - node_cpu_utilization
          - node_memory_utilization
          - node_network_total_bytes
          - node_cpu_reserved_capacity
          - node_memory_reserved_capacity
          - node_number_of_running_pods
          - node_number_of_running_containers
      - dimensions: [[ClusterName]]
        metric_name_selectors:
          - node_cpu_utilization
          - node_memory_utilization
          - node_network_total_bytes
          - node_cpu_reserved_capacity
          - node_memory_reserved_capacity
          - node_number_of_running_pods
          - node_number_of_running_containers
          - node_cpu_usage_total
          - node_cpu_limit
          - node_memory_working_set
          - node_memory_limit

      # pod metrics
      - dimensions: [[PodName, Namespace, ClusterName], [Service, Namespace, ClusterName], [Namespace, ClusterName], [ClusterName]]
        metric_name_selectors:
          - pod_cpu_utilization
          - pod_memory_utilization
          - pod_network_rx_bytes
          - pod_network_tx_bytes
          - pod_cpu_utilization_over_pod_limit
          - pod_memory_utilization_over_pod_limit
      - dimensions: [[PodName, Namespace, ClusterName], [ClusterName]]
        metric_name_selectors:
          - pod_cpu_reserved_capacity
          - pod_memory_reserved_capacity
      - dimensions: [[PodName, Namespace, ClusterName]]
        metric_name_selectors:
          - pod_number_of_container_restarts

      # cluster metrics
      - dimensions: [[ClusterName]]
        metric_name_selectors:
          - cluster_node_count
          - cluster_failed_node_count

      # service metrics
      - dimensions: [[Service, Namespace, ClusterName], [ClusterName]]
        metric_name_selectors:
          - service_number_of_running_pods

      # node fs metrics
      - dimensions: [[NodeName, InstanceId, ClusterName], [ClusterName]]
        metric_name_selectors:
          - node_filesystem_utilization

      # namespace metrics
      - dimensions: [[Namespace, ClusterName], [ClusterName]]
        metric_name_selectors:
          - namespace_number_of_running_pods

service:
  pipelines:
    metrics:
      receivers: [awscontainerinsightreceiver]
      processors: [batch/metrics]
      exporters: [awsemf]

  extensions: [health_check]
`,
      },
    });

    otelConfigMap.node.addDependency(otelNamespace);

    const otelDaemon = cluster.addManifest("my-otel-daemon", {
      apiVersion: "apps/v1",
      kind: "DaemonSet",
      metadata: {
        name: "aws-otel-eks-ci",
        namespace: otelNamespaceName,
      },
      spec: {
        selector: {
          matchLabels: {
            name: "aws-otel-eks-ci",
          },
        },
        template: {
          metadata: {
            labels: {
              name: "aws-otel-eks-ci",
            },
          },
          spec: {
            containers: [
              {
                name: "aws-otel-collector",
                image:
                  "public.ecr.aws/aws-observability/aws-otel-collector:v0.22.0",
                env: [
                  {
                    name: "K8S_NODE_NAME",
                    valueFrom: {
                      fieldRef: {
                        fieldPath: "spec.nodeName",
                      },
                    },
                  },
                  {
                    name: "HOST_IP",
                    valueFrom: {
                      fieldRef: {
                        fieldPath: "status.hostIP",
                      },
                    },
                  },
                  {
                    name: "HOST_NAME",
                    valueFrom: {
                      fieldRef: {
                        fieldPath: "spec.nodeName",
                      },
                    },
                  },
                  {
                    name: "K8S_NAMESPACE",
                    valueFrom: {
                      fieldRef: {
                        fieldPath: "metadata.namespace",
                      },
                    },
                  },
                ],
                imagePullPolicy: "Always",
                command: [
                  "/awscollector",
                  "--config=/conf/otel-agent-config.yaml",
                ],
                volumeMounts: [
                  {
                    name: "rootfs",
                    mountPath: "/rootfs",
                    readOnly: true,
                  },
                  {
                    name: "dockersock",
                    mountPath: "/var/run/docker.sock",
                    readOnly: true,
                  },
                  {
                    name: "containerdsock",
                    mountPath: "/run/containerd/containerd.sock",
                  },
                  {
                    name: "varlibdocker",
                    mountPath: "/var/lib/docker",
                    readOnly: true,
                  },
                  {
                    name: "sys",
                    mountPath: "/sys",
                    readOnly: true,
                  },
                  {
                    name: "devdisk",
                    mountPath: "/dev/disk",
                    readOnly: true,
                  },
                  {
                    name: "otel-agent-config-vol",
                    mountPath: "/conf",
                  },
                ],
                resources: {
                  limits: {
                    cpu: "200m",
                    memory: "200Mi",
                  },
                  requests: {
                    cpu: "200m",
                    memory: "200Mi",
                  },
                },
              },
            ],
            volumes: [
              {
                configMap: {
                  name: "otel-agent-conf",
                  items: [
                    {
                      key: "otel-agent-config",
                      path: "otel-agent-config.yaml",
                    },
                  ],
                },
                name: "otel-agent-config-vol",
              },
              {
                name: "rootfs",
                hostPath: {
                  path: "/",
                },
              },
              {
                name: "dockersock",
                hostPath: {
                  path: "/var/run/docker.sock",
                },
              },
              {
                name: "varlibdocker",
                hostPath: {
                  path: "/var/lib/docker",
                },
              },
              {
                name: "containerdsock",
                hostPath: {
                  path: "/run/containerd/containerd.sock",
                },
              },
              {
                name: "sys",
                hostPath: {
                  path: "/sys",
                },
              },
              {
                name: "devdisk",
                hostPath: {
                  path: "/dev/disk/",
                },
              },
            ],
            serviceAccountName: otelServiceAccountName,
          },
        },
      },
    });

    otelDaemon.node.addDependency(otelNamespace);
    otelDaemon.node.addDependency(otelConfigMap);
    otelDaemon.node.addDependency(otelRoleBinding);
  }
}
