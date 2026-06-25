#!/usr/bin/env bash
# Todo List Plugin for bootstrap CLI

TODO_FILE="$HOME/.local/share/bootstrap/todo.txt"

main() {
    mkdir -p "$(dirname "$TODO_FILE")"
    [ ! -f "$TODO_FILE" ] && touch "$TODO_FILE"

    local action="${1:-list}"
    case "$action" in
        add)
            shift
            if [ -z "$*" ]; then
                log_error "Please specify a task to add."
                echo "Usage: b todo add <task description>"
                return 1
            fi
            echo "[ ] $*" >> "$TODO_FILE"
            log_success "Added task: $*"
            ;;
        list)
            if [ ! -s "$TODO_FILE" ]; then
                log_info "Your todo list is empty. Add a task with: b todo add <task>"
                return 0
            fi
            echo -e "${BLUE}--- YOUR TODO LIST ---${NC}"
            local line_num=1
            while IFS= read -r line || [ -n "$line" ]; do
                # Highlight completed tasks
                if [[ "$line" == "[\x]"* || "$line" == "[x]"* ]]; then
                    echo -e "  ${line_num}. ${GREEN}${line}${NC}"
                else
                    echo -e "  ${line_num}. ${line}"
                fi
                line_num=$((line_num + 1))
            done < "$TODO_FILE"
            ;;
        done)
            shift
            local task_num="${1:-}"
            if [[ ! "$task_num" =~ ^[0-9]+$ ]]; then
                log_error "Please specify a valid task number."
                echo "Usage: b todo done <number>"
                return 1
            fi
            
            local total_tasks
            total_tasks=$(wc -l < "$TODO_FILE")
            if [ "$task_num" -lt 1 ] || [ "$task_num" -gt "$total_tasks" ]; then
                log_error "Task number out of range (1-$total_tasks)."
                return 1
            fi
            
            # Update the task at line task_num to be marked [x]
            local temp_file
            temp_file=$(mktemp)
            local line_num=1
            while IFS= read -r line || [ -n "$line" ]; do
                if [ "$line_num" -eq "$task_num" ]; then
                    # Replace [ ] with [x]
                    echo "${line/\[ \]/\[x\]}" >> "$temp_file"
                else
                    echo "$line" >> "$temp_file"
                fi
                line_num=$((line_num + 1))
            done < "$TODO_FILE"
            mv "$temp_file" "$TODO_FILE"
            log_success "Marked task #$task_num as completed."
            ;;
        rm|remove)
            shift
            local task_num="${1:-}"
            if [[ ! "$task_num" =~ ^[0-9]+$ ]]; then
                log_error "Please specify a valid task number to remove."
                echo "Usage: b todo rm <number>"
                return 1
            fi
            
            local total_tasks
            total_tasks=$(wc -l < "$TODO_FILE")
            if [ "$task_num" -lt 1 ] || [ "$task_num" -gt "$total_tasks" ]; then
                log_error "Task number out of range (1-$total_tasks)."
                return 1
            fi
            
            # Remove the line at task_num
            local temp_file
            temp_file=$(mktemp)
            local line_num=1
            while IFS= read -r line || [ -n "$line" ]; do
                if [ "$line_num" -ne "$task_num" ]; then
                    echo "$line" >> "$temp_file"
                fi
                line_num=$((line_num + 1))
            done < "$TODO_FILE"
            mv "$temp_file" "$TODO_FILE"
            log_success "Removed task #$task_num."
            ;;
        clear)
            > "$TODO_FILE"
            log_success "Cleared all tasks from your todo list."
            ;;
        --help|-h)
            echo "Usage: b todo [action] [args]"
            echo ""
            echo "Actions:"
            echo "  list               Show all tasks (default)"
            echo "  add <task>         Add a new task"
            echo "  done <number>      Mark a task as completed"
            echo "  rm <number>        Remove a task"
            echo "  clear              Delete all tasks"
            return 0
            ;;
        *)
            log_error "Unknown action: $action"
            echo "Run 'b todo --help' for usage instructions."
            return 1
            ;;
    esac
}

main "$@"
