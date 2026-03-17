package thunder

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
)

// ValidateGroupAddress checks if an address matches the group pattern and exists in Thunder IDP.
// Expected format: <group-name>-group@<domain>
func ValidateGroupAddress(email, host, port string, tokenRefreshSeconds int) (bool, error) {
	log.Printf("      ┌─ Thunder Group Validation ────")
	log.Printf("      │ Email: %s", email)

	parts := strings.Split(email, "@")
	if len(parts) != 2 {
		log.Printf("      │ ✗ Invalid email format")
		log.Printf("      └──────────────────────────────")
		return false, nil
	}

	localPart := parts[0]
	domain := parts[1]

	if !strings.HasSuffix(localPart, "-group") {
		log.Printf("      │ ✗ Not a group address")
		log.Printf("      └──────────────────────────────")
		return false, nil
	}

	groupName := strings.TrimSuffix(localPart, "-group")
	if groupName == "" {
		log.Printf("      │ ✗ Empty group name")
		log.Printf("      └──────────────────────────────")
		return false, nil
	}

	log.Printf("      │ Group: %s", groupName)
	log.Printf("      │ Domain: %s", domain)

	auth, err := GetAuth(host, port, tokenRefreshSeconds)
	if err != nil {
		log.Printf("      │ ⚠ Auth failed: %v", err)
		log.Printf("      └──────────────────────────────")
		return false, err
	}

	ouID, err := GetOrgUnitIDForDomain(domain, host, port, tokenRefreshSeconds)
	if err != nil {
		log.Printf("      │ ⚠ Failed to get OU ID: %v", err)
		log.Printf("      └──────────────────────────────")
		return false, err
	}

	log.Printf("      │ OU ID: %s", ouID)

	client := GetHTTPClient()
	escapedGroupName := escapeFilterValue(groupName)
	filter := fmt.Sprintf("name eq \"%s\"", escapedGroupName)

	baseURL := fmt.Sprintf("https://%s:%s/groups", host, port)
	req, err := http.NewRequest("GET", baseURL, nil)
	if err != nil {
		log.Printf("      │ ✗ Failed to create request: %v", err)
		log.Printf("      └──────────────────────────────")
		return false, err
	}

	q := req.URL.Query()
	q.Add("filter", filter)
	req.URL.RawQuery = q.Encode()

	req.Header.Set("Authorization", "Bearer "+auth.BearerToken)
	req.Header.Set("Content-Type", "application/json")

	log.Printf("      │ Query: %s", req.URL.String())

	resp, err := client.Do(req)
	if err != nil {
		log.Printf("      │ ✗ Request failed: %v", err)
		log.Printf("      └──────────────────────────────")
		return false, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		log.Printf("      │ ⚠ Unexpected status: %d", resp.StatusCode)
		log.Printf("      └──────────────────────────────")
		return false, fmt.Errorf("unexpected status: %d", resp.StatusCode)
	}

	var groupsResp GroupsResponse
	if err := json.NewDecoder(resp.Body).Decode(&groupsResp); err != nil {
		log.Printf("      │ ✗ Failed to parse response: %v", err)
		log.Printf("      └──────────────────────────────")
		return false, err
	}

	log.Printf("      │ Total results: %d", groupsResp.TotalResults)

	if groupsResp.TotalResults == 0 {
		log.Printf("      │ ✗ Group not found in Thunder")
		log.Printf("      └──────────────────────────────")
		return false, nil
	}

	for _, group := range groupsResp.Groups {
		if group.OrganizationUnitID == ouID && group.Name == groupName {
			log.Printf("      │ ✓ Group found and OU matches")
			log.Printf("      └──────────────────────────────")
			return true, nil
		}
	}

	log.Printf("      │ ✗ Group found but OU/name mismatch")
	log.Printf("      └──────────────────────────────")
	return false, nil
}
