# 指定 apiserver 地址
KUBE_APISERVER="https://192.168.0.7:6443"

# 生成 Bootstrap Token
TOKEN_ID=$(head -c 6 /dev/urandom | md5sum | head -c 6)
TOKEN_SECRET=$(head -c 16 /dev/urandom | md5sum | head -c 16)
BOOTSTRAP_TOKEN="${TOKEN_ID}.${TOKEN_SECRET}"
echo "Bootstrap Token: ${BOOTSTRAP_TOKEN}"

# 使用secret存储token 
cat >> bootstrap-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  # 名字必须该格式
  name: bootstrap-token-${TOKEN_ID}
  namespace: kube-system
# 必须该类型
type: bootstrap.kubernetes.io/token
stringData:
  description: "The default bootstrap token."
  token-id: ${TOKEN_ID}
  token-secret: ${TOKEN_SECRET}
  expiration: $(date -d'+2 day' -u +"%Y-%m-%dT%H:%M:%SZ")
  usage-bootstrap-authentication: "true"
  usage-bootstrap-signing: "true"
EOF

kubectl apply -f bootstrap-secret.yaml

# 生成 kubelet bootstrap kubeconfig 配置文件
kubectl config set-cluster kubernetes \
  --certificate-authority=/opt/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=bootstrap.kubeconfig
kubectl config set-credentials "system:bootstrap:${TOKEN_ID}" \
  --token=${BOOTSTRAP_TOKEN} \
  --kubeconfig=bootstrap.kubeconfig
kubectl config set-context default \
  --cluster=kubernetes \
  --user="system:bootstrap:${TOKEN_ID}" \
  --kubeconfig=bootstrap.kubeconfig
kubectl config use-context default --kubeconfig=bootstrap.kubeconfig

# 允许 kubelet tls bootstrap 创建 CSR 请求
kubectl create clusterrolebinding create-csrs-for-bootstrapping \
  --clusterrole=system:node-bootstrapper \
  --group=system:bootstrappers
