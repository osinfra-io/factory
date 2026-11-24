// Package floor provides a typed client over tofu-controller Terraform
// objects, reading their status and approving pending plans via
// server-side apply.
package floor

import "k8s.io/apimachinery/pkg/runtime/schema"

// TerraformGVK identifies the tofu-controller Terraform custom resource.
var TerraformGVK = schema.GroupVersionKind{
	Group:   "infra.contrib.fluxcd.io",
	Version: "v1alpha2",
	Kind:    "Terraform",
}

// GitRepositoryGVK identifies the source-controller GitRepository custom
// resource referenced by a Terraform object's spec.sourceRef.
var GitRepositoryGVK = schema.GroupVersionKind{
	Group:   "source.toolkit.fluxcd.io",
	Version: "v1",
	Kind:    "GitRepository",
}

const (
	labelPullRequestID   = "infra.weave.works/pr-id"
	labelPrimaryResource = "infra.weave.works/primary-resource"

	annotationReview = "floor.osinfra.io/review"
)

// Workspace is the flattened, typed view of a Terraform object that
// floor-api exposes to callers.
type Workspace struct {
	Name         string `json:"name"`
	Namespace    string `json:"namespace"`
	Path         string `json:"path"`
	SourceBranch string `json:"sourceBranch"`
	Phase        string `json:"phase"`
	// Message is the controller message behind Phase, such as a plan error.
	Message     string `json:"message,omitempty"`
	PendingPlan string `json:"pendingPlan"`
	// Approved is true once the pending plan has been approved but not yet applied.
	Approved bool `json:"approved"`
	// DependsOn lists the namespace/name of Terraform objects this one waits on.
	DependsOn []string `json:"dependsOn,omitempty"`
	// ApprovedBy, ApprovedAt and ApprovedPlan describe the last approval
	// recorded through floor-api.
	ApprovedBy          string `json:"approvedBy,omitempty"`
	ApprovedAt          string `json:"approvedAt,omitempty"`
	ApprovedPlan        string `json:"approvedPlan,omitempty"`
	LastAppliedRevision string `json:"lastAppliedRevision"`
	Review              string `json:"review"`
	Destroy             bool   `json:"destroy"`
	PlanOnly            bool   `json:"planOnly"`
	PullRequest         int    `json:"pullRequest"`
	PrimaryResource     string `json:"primaryResource"`
}
