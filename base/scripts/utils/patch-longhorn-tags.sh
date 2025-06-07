#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="longhorn-system"
LABEL_KEY="longhorn-true"
MAX_ATTEMPTS=25
SLEEP_INTERVAL=5

echo "🔍 Verifying nodes with label $LABEL_KEY..."
nodes=$(kubectl get nodes -l $LABEL_KEY -o name)

if [[ -z "$nodes" ]]; then
  echo "⚠️  No nodes found with label '$LABEL_KEY'."
  echo "   Check: kubectl get nodes --show-labels"
  exit 1
fi

echo "📋 Nodes to process:"
echo "$nodes"
echo

echo "🔖 Patching Kubernetes node annotations (longhorn.io/node-tags)..."
echo "$nodes" | while read -r node; do
  echo "  → Annotating $node ..."
  kubectl patch "$node" \
    --type=merge \
    -p '{"metadata": {"annotations": {"longhorn.io/node-tags": "[\"longhorn-true\"]"}}}'
done

echo
echo "🏷️  Patching Longhorn CRD nodes (.spec.tags)…"
echo "$nodes" | sed 's|^node/||' | while read -r node; do
  echo "  → CRD node: $node"

  for i in $(seq 1 $MAX_ATTEMPTS); do
    status=$(kubectl get -n $NAMESPACE nodes.longhorn.io "$node" \
      -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    if [[ "$status" != "True" ]]; then
      echo "     ⏳ Not Ready ($status). retry $i/$MAX_ATTEMPTS…"
      sleep $SLEEP_INTERVAL
      continue
    fi

    echo "     ✅ Ready! Patching tags…"
    kubectl patch -n $NAMESPACE nodes.longhorn.io "$node" \
      --type=merge \
      -p '{"spec": {"tags": ["longhorn-true"]}}'
    echo "     ✔️  Patched .spec.tags for $node"
    break
  done
done

echo
echo "🎉 Done patching Longhorn annotations & tags."
