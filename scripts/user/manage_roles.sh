#!/bin/bash

# ============================================
#  Silver Mail - Manage Role Assignments
# ============================================
#
# This script allows you to:
# - Transfer role assignments from one user to another
# - Add a user to a role mailbox
# - Remove a user from a role mailbox
# - List all role assignments for a user or role
#

# -------------------------------
# Configuration
# -------------------------------
# Colors
CYAN="\033[0;36m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_DIR="$(cd "${SCRIPT_DIR}/../../services" && pwd)"

# -------------------------------
# Helper Functions
# -------------------------------

show_usage() {
	echo -e "${CYAN}Usage:${NC}"
	echo -e "  ${GREEN}Transfer role from one user to another:${NC}"
	echo -e "    $0 transfer <source-user>@<domain> <target-user>@<domain> <role-name>@<domain>"
	echo ""
	echo -e "  ${GREEN}Add user to role:${NC}"
	echo -e "    $0 add <user>@<domain> <role-name>@<domain>"
	echo ""
	echo -e "  ${GREEN}Remove user from role:${NC}"
	echo -e "    $0 remove <user>@<domain> <role-name>@<domain>"
	echo ""
	echo -e "  ${GREEN}List assignments for a user:${NC}"
	echo -e "    $0 list-user <user>@<domain>"
	echo ""
	echo -e "  ${GREEN}List users assigned to a role:${NC}"
	echo -e "    $0 list-role <role-name>@<domain>"
	echo ""
	echo -e "  ${GREEN}List all role assignments:${NC}"
	echo -e "    $0 list-all"
	echo ""
	echo -e "${YELLOW}Examples:${NC}"
	echo -e "  $0 transfer alice@example.com bob@example.com info@example.com"
	echo -e "  $0 add charlie@example.com support@example.com"
	echo -e "  $0 remove alice@example.com sales@example.com"
	echo -e "  $0 list-user alice@example.com"
	echo -e "  $0 list-role info@example.com"
	exit 1
}

# Get SMTP container
get_smtp_container() {
	SMTP_CONTAINER=$(cd "${SERVICES_DIR}" && docker compose ps -q smtp-server 2>/dev/null)
	if [ -z "$SMTP_CONTAINER" ]; then
		echo -e "${RED}✗ SMTP container not found. Is Docker Compose running?${NC}"
		exit 1
	fi
	echo "$SMTP_CONTAINER"
}

# Parse email to get username and domain
parse_email() {
	local email="$1"
	if [[ ! "$email" =~ ^(.+)@(.+)$ ]]; then
		echo -e "${RED}✗ Invalid email format: $email${NC}"
		exit 1
	fi
	echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
}

# Get user ID
get_user_id() {
	local smtp_container="$1"
	local username="$2"
	local domain="$3"

	local user_id=$(docker exec "$smtp_container" bash -c "
        sqlite3 /app/data/databases/shared.db \"
            SELECT u.id FROM users u
            INNER JOIN domains d ON u.domain_id = d.id
            WHERE u.username='${username}' AND d.domain='${domain}' AND u.enabled=1;
        \"" 2>/dev/null | tr -d '\n\r')

	if [ -z "$user_id" ]; then
		echo -e "${RED}✗ User ${username}@${domain} not found${NC}"
		return 1
	fi
	echo "$user_id"
}

# Get role mailbox ID
get_role_id() {
	local smtp_container="$1"
	local role_email="$2"

	local role_id=$(docker exec "$smtp_container" bash -c "
        sqlite3 /app/data/databases/shared.db \"
            SELECT id FROM role_mailboxes
            WHERE email='${role_email}' AND enabled=1;
        \"" 2>/dev/null | tr -d '\n\r')

	if [ -z "$role_id" ]; then
		echo -e "${RED}✗ Role mailbox ${role_email} not found${NC}"
		return 1
	fi
	echo "$role_id"
}

# Add user to role
add_user_to_role() {
	local smtp_container="$1"
	local user_email="$2"
	local role_email="$3"

	read -r username domain <<<"$(parse_email "$user_email")"

	echo -e "${YELLOW}Adding ${user_email} to role ${role_email}...${NC}"

	local user_id=$(get_user_id "$smtp_container" "$username" "$domain") || return 1
	local role_id=$(get_role_id "$smtp_container" "$role_email") || return 1

	# Check if already assigned
	local exists=$(docker exec "$smtp_container" bash -c "
        sqlite3 /app/data/databases/shared.db \"
            SELECT COUNT(*) FROM user_role_assignments
            WHERE user_id=${user_id} AND role_mailbox_id=${role_id};
        \"" 2>/dev/null | tr -d '\n\r')

	if [ "$exists" != "0" ]; then
		# Check if it's inactive and reactivate it
		local is_active=$(docker exec "$smtp_container" bash -c "
            sqlite3 /app/data/databases/shared.db \"
                SELECT is_active FROM user_role_assignments
                WHERE user_id=${user_id} AND role_mailbox_id=${role_id};
            \"" 2>/dev/null | tr -d '\n\r')

		if [ "$is_active" = "0" ]; then
			docker exec "$smtp_container" bash -c "
                sqlite3 /app/data/databases/shared.db \"
                    UPDATE user_role_assignments
                    SET is_active=1, assigned_at=datetime('now')
                    WHERE user_id=${user_id} AND role_mailbox_id=${role_id};
                \""
			echo -e "${GREEN}✓ Reactivated assignment: ${user_email} → ${role_email}${NC}"
		else
			echo -e "${YELLOW}⚠ User ${user_email} is already assigned to ${role_email}${NC}"
		fi
		return 0
	fi

	# Create new assignment
	docker exec "$smtp_container" bash -c "
        sqlite3 /app/data/databases/shared.db \"
            INSERT INTO user_role_assignments (user_id, role_mailbox_id, assigned_at, is_active)
            VALUES (${user_id}, ${role_id}, datetime('now'), 1);
        \""

	if [ $? -eq 0 ]; then
		echo -e "${GREEN}✓ Successfully assigned ${user_email} to ${role_email}${NC}"
		return 0
	else
		echo -e "${RED}✗ Failed to assign user to role${NC}"
		return 1
	fi
}

# Remove user from role
remove_user_from_role() {
	local smtp_container="$1"
	local user_email="$2"
	local role_email="$3"

	read -r username domain <<<"$(parse_email "$user_email")"

	echo -e "${YELLOW}Removing ${user_email} from role ${role_email}...${NC}"

	local user_id=$(get_user_id "$smtp_container" "$username" "$domain") || return 1
	local role_id=$(get_role_id "$smtp_container" "$role_email") || return 1

	# Set is_active to 0 instead of deleting (keeps audit trail)
	docker exec "$smtp_container" bash -c "
        sqlite3 /app/data/databases/shared.db \"
            UPDATE user_role_assignments
            SET is_active=0
            WHERE user_id=${user_id} AND role_mailbox_id=${role_id};
        \""

	local rows_affected=$(docker exec "$smtp_container" bash -c "
        sqlite3 /app/data/databases/shared.db \"
            SELECT changes();
        \"" 2>/dev/null | tr -d '\n\r')

	if [ "$rows_affected" != "0" ]; then
		echo -e "${GREEN}✓ Successfully removed ${user_email} from ${role_email}${NC}"
		return 0
	else
		echo -e "${YELLOW}⚠ User ${user_email} was not assigned to ${role_email}${NC}"
		return 1
	fi
}

# Transfer role from one user to another
transfer_role() {
	local smtp_container="$1"
	local source_email="$2"
	local target_email="$3"
	local role_email="$4"

	echo -e "${CYAN}========================================${NC}"
	echo -e "${CYAN}Transferring Role Assignment${NC}"
	echo -e "${CYAN}========================================${NC}"
	echo -e "Role: ${BLUE}${role_email}${NC}"
	echo -e "From: ${YELLOW}${source_email}${NC}"
	echo -e "To:   ${GREEN}${target_email}${NC}"
	echo ""

	# Remove from source user
	if remove_user_from_role "$smtp_container" "$source_email" "$role_email"; then
		# Add to target user
		if add_user_to_role "$smtp_container" "$target_email" "$role_email"; then
			echo ""
			echo -e "${GREEN}✓ Role successfully transferred!${NC}"
			return 0
		else
			echo -e "${RED}✗ Failed to add role to target user. Restoring source user...${NC}"
			add_user_to_role "$smtp_container" "$source_email" "$role_email"
			return 1
		fi
	else
		return 1
	fi
}

# List assignments for a user
list_user_assignments() {
	local smtp_container="$1"
	local user_email="$2"

	read -r username domain <<<"$(parse_email "$user_email")"

	echo -e "${CYAN}========================================${NC}"
	echo -e "${CYAN}Role Assignments for: ${GREEN}${user_email}${NC}"
	echo -e "${CYAN}========================================${NC}"

	docker exec "$smtp_container" bash -c "
        sqlite3 /app/data/databases/shared.db \"
            SELECT
                CASE WHEN ura.is_active=1 THEN '✓' ELSE '✗' END || ' ' || r.email ||
                ' (assigned: ' || datetime(ura.assigned_at, 'localtime') || ')'
            FROM user_role_assignments ura
            INNER JOIN users u ON ura.user_id = u.id
            INNER JOIN role_mailboxes r ON ura.role_mailbox_id = r.id
            INNER JOIN domains d ON u.domain_id = d.id
            WHERE u.username='${username}' AND d.domain='${domain}'
            ORDER BY ura.is_active DESC, r.email;
        \"" 2>/dev/null

	if [ $? -ne 0 ]; then
		echo -e "${YELLOW}No role assignments found${NC}"
	fi
}

# List users assigned to a role
list_role_users() {
	local smtp_container="$1"
	local role_email="$2"

	echo -e "${CYAN}========================================${NC}"
	echo -e "${CYAN}Users assigned to: ${GREEN}${role_email}${NC}"
	echo -e "${CYAN}========================================${NC}"

	docker exec "$smtp_container" bash -c "
        sqlite3 /app/data/databases/shared.db \"
            SELECT
                CASE WHEN ura.is_active=1 THEN '✓' ELSE '✗' END || ' ' ||
                u.username || '@' || d.domain ||
                ' (assigned: ' || datetime(ura.assigned_at, 'localtime') || ')'
            FROM user_role_assignments ura
            INNER JOIN users u ON ura.user_id = u.id
            INNER JOIN role_mailboxes r ON ura.role_mailbox_id = r.id
            INNER JOIN domains d ON u.domain_id = d.id
            WHERE r.email='${role_email}'
            ORDER BY ura.is_active DESC, u.username;
        \"" 2>/dev/null

	if [ $? -ne 0 ]; then
		echo -e "${YELLOW}No users assigned to this role${NC}"
	fi
}

# List all role assignments
list_all_assignments() {
	local smtp_container="$1"

	echo -e "${CYAN}========================================${NC}"
	echo -e "${CYAN}All Role Assignments${NC}"
	echo -e "${CYAN}========================================${NC}"

	docker exec "$smtp_container" bash -c "
        sqlite3 /app/data/databases/shared.db \"
            SELECT
                CASE WHEN ura.is_active=1 THEN '✓' ELSE '✗' END || ' ' ||
                u.username || '@' || d.domain || ' → ' || r.email
            FROM user_role_assignments ura
            INNER JOIN users u ON ura.user_id = u.id
            INNER JOIN role_mailboxes r ON ura.role_mailbox_id = r.id
            INNER JOIN domains d ON u.domain_id = d.id
            ORDER BY ura.is_active DESC, d.domain, u.username, r.email;
        \"" 2>/dev/null

	if [ $? -ne 0 ]; then
		echo -e "${YELLOW}No role assignments found${NC}"
	fi
}

# -------------------------------
# Main Script
# -------------------------------

# Check arguments
if [ $# -lt 1 ]; then
	show_usage
fi

COMMAND="$1"
shift

# Get SMTP container
SMTP_CONTAINER=$(get_smtp_container)

case "$COMMAND" in
transfer)
	if [ $# -ne 3 ]; then
		echo -e "${RED}✗ Transfer requires 3 arguments: source-user target-user role${NC}"
		show_usage
	fi
	transfer_role "$SMTP_CONTAINER" "$1" "$2" "$3"
	;;

add)
	if [ $# -ne 2 ]; then
		echo -e "${RED}✗ Add requires 2 arguments: user role${NC}"
		show_usage
	fi
	add_user_to_role "$SMTP_CONTAINER" "$1" "$2"
	;;

remove)
	if [ $# -ne 2 ]; then
		echo -e "${RED}✗ Remove requires 2 arguments: user role${NC}"
		show_usage
	fi
	remove_user_from_role "$SMTP_CONTAINER" "$1" "$2"
	;;

list-user)
	if [ $# -ne 1 ]; then
		echo -e "${RED}✗ List-user requires 1 argument: user email${NC}"
		show_usage
	fi
	list_user_assignments "$SMTP_CONTAINER" "$1"
	;;

list-role)
	if [ $# -ne 1 ]; then
		echo -e "${RED}✗ List-role requires 1 argument: role email${NC}"
		show_usage
	fi
	list_role_users "$SMTP_CONTAINER" "$1"
	;;

list-all)
	list_all_assignments "$SMTP_CONTAINER"
	;;

*)
	echo -e "${RED}✗ Unknown command: $COMMAND${NC}"
	show_usage
	;;
esac
