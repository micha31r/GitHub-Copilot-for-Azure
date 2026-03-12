#!/bin/bash
# thinking-log.sh — Unified Copilot CLI hook logger
# Writes to summary.log (compact) and detailed.jsonl (full JSON)
# Each CLI session gets its own logs/<session-id>/ directory
# PASSIVE OBSERVER: No stdout output, silent failures, always exit 0

{
    EVENT="$HOOK_EVENT"
    [ -z "$EVENT" ] && exit 0

    INPUT="$(cat)"
    [ -z "$INPUT" ] && exit 0

    BASE_LOG_DIR="logs"
    mkdir -p "$BASE_LOG_DIR"

    # Extract common fields
    TS_MS="$(echo "$INPUT" | jq -r '.timestamp // empty')"
    CWD="$(echo "$INPUT" | jq -r '.cwd // empty')"

    # Convert epoch ms to time string
    if [ -n "$TS_MS" ]; then
        TS_SEC=$((TS_MS / 1000))
        TS_FRAC=$(printf "%03d" $((TS_MS % 1000)))
        if date --version >/dev/null 2>&1; then
            TIME_STR="$(date -u -d "@$TS_SEC" +%H:%M:%S).$TS_FRAC"
            ISO_STR="$(date -u -d "@$TS_SEC" +%Y-%m-%dT%H:%M:%S).${TS_FRAC}Z"
        else
            TIME_STR="$(date -u -r "$TS_SEC" +%H:%M:%S 2>/dev/null || date -u +%H:%M:%S).$TS_FRAC"
            ISO_STR="$(date -u -r "$TS_SEC" +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%S).${TS_FRAC}Z"
        fi
    else
        TIME_STR="$(date -u +%H:%M:%S.000)"
        ISO_STR="$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
    fi

    # Helper: truncate string (tripled limits)
    truncate() {
        local s="$1" max="${2:-240}"
        s="$(echo "$s" | tr '\n' '\\' | sed 's/\\/\\n/g')"
        if [ ${#s} -le "$max" ]; then
            echo "$s"
        else
            echo "${s:0:$max}..."
        fi
    }

    # Helper: safely parse toolArgs JSON string
    parse_tool_args() {
        local raw="$1"
        [ -z "$raw" ] && return 1
        echo "$raw" | jq -e '.' >/dev/null 2>&1 && echo "$raw" | jq -c '.' && return 0
        return 1
    }

    # Helper: detect and copy temp files from tool results
    copy_temp_files() {
        local result_text="$1" tool_name="$2" target_dir="$3"
        [ -z "$result_text" ] && return
        local counter=0
        echo "$result_text" | grep -oP 'Saved to:\s*\K[^\s"]+' 2>/dev/null | while read -r src_path; do
            if [ -f "$src_path" ]; then
                counter=$((counter + 1))
                local ext="${src_path##*.}"
                [ "$ext" = "$src_path" ] && ext="txt"
                cp "$src_path" "$target_dir/temp-${tool_name}-${counter}.${ext}" 2>/dev/null
            fi
        done
    }

    # --- Per-session log directory via parent PID ---
    # Use parent PID directly as folder name — same CLI chat process = same folder
    # All events with the same PPID append to the same folder (no archiving)
    PPID_VAL="$PPID"
    LOG_DIR="$BASE_LOG_DIR/$PPID_VAL"

    mkdir -p "$LOG_DIR"
    SUMMARY="$LOG_DIR/summary.log"
    DETAILED="$LOG_DIR/detailed.jsonl"

    SUMMARY_LINE=""

    case "$EVENT" in
        sessionStart)
            SRC="$(echo "$INPUT" | jq -r '.source // empty')"
            SUMMARY_LINE="[$TIME_STR] SESSION>  src=$SRC cwd=$CWD ppid=$PPID_VAL"
            jq -n -c \
                --arg event "$EVENT" --arg ts "$ISO_STR" --arg tsMs "$TS_MS" \
                --arg source "$SRC" --arg cwd "$CWD" --argjson ppid "$PPID_VAL" \
                --arg initialPrompt "$(echo "$INPUT" | jq -r '.initialPrompt // empty')" \
                '{event:$event,ts:$ts,tsMs:($tsMs|tonumber),ppid:$ppid,source:$source,cwd:$cwd,initialPrompt:$initialPrompt}' \
                >> "$DETAILED"
            ;;

        sessionEnd)
            REASON="$(echo "$INPUT" | jq -r '.reason // empty')"
            SUMMARY_LINE="[$TIME_STR] SESSION<  reason=$REASON"
            jq -n -c \
                --arg event "$EVENT" --arg ts "$ISO_STR" --arg tsMs "$TS_MS" \
                --arg reason "$REASON" --arg cwd "$CWD" --argjson ppid "$PPID_VAL" \
                '{event:$event,ts:$ts,tsMs:($tsMs|tonumber),ppid:$ppid,reason:$reason,cwd:$cwd}' \
                >> "$DETAILED"
            ;;

        userPromptSubmitted)
            PROMPT="$(echo "$INPUT" | jq -r '.prompt // empty')"
            PREVIEW="$(truncate "$PROMPT" 180)"
            LEN="${#PROMPT}"
            SUMMARY_LINE="[$TIME_STR] PROMPT    \"$PREVIEW\" ($LEN chars)"
            jq -n -c \
                --arg event "$EVENT" --arg ts "$ISO_STR" --arg tsMs "$TS_MS" \
                --arg prompt "$PROMPT" --arg cwd "$CWD" \
                '{event:$event,ts:$ts,tsMs:($tsMs|tonumber),prompt:$prompt,cwd:$cwd}' \
                >> "$DETAILED"
            ;;

        preToolUse)
            TOOL_NAME="$(echo "$INPUT" | jq -r '.toolName // empty')"
            ARGS_RAW="$(echo "$INPUT" | jq -r '.toolArgs // empty')"
            ARGS_PARSED="$(parse_tool_args "$ARGS_RAW")" || ARGS_PARSED=""
            DETAIL=""
            META=""

            case "$TOOL_NAME" in
                bash|powershell)
                    CMD="$(echo "$ARGS_PARSED" | jq -r '.command // empty' 2>/dev/null)"
                    DETAIL="cmd: $(truncate "$CMD" 210)"
                    ;;
                task)
                    AGENT_TYPE="$(echo "$ARGS_PARSED" | jq -r '.agent_type // "?"' 2>/dev/null)"
                    MODE="$(echo "$ARGS_PARSED" | jq -r '.mode // "sync"' 2>/dev/null)"
                    DESC="$(echo "$ARGS_PARSED" | jq -r '.description // empty' 2>/dev/null)"
                    PROMPT="$(echo "$ARGS_PARSED" | jq -r '.prompt // empty' 2>/dev/null)"
                    MODE_SHORT="$([ "$MODE" = "background" ] && echo "bg" || echo "sync")"
                    DETAIL="agent:$AGENT_TYPE mode:$MODE_SHORT"
                    [ -n "$DESC" ] && DETAIL="$DETAIL desc:\"$(truncate "$DESC" 90)\""
                    [ -n "$PROMPT" ] && DETAIL="$DETAIL prompt:\"$(truncate "$PROMPT" 120)\""
                    ;;
                skill)
                    SKILL_NAME="$(echo "$ARGS_PARSED" | jq -r '.skill // "?"' 2>/dev/null)"
                    DETAIL="name:$SKILL_NAME"
                    META="$(jq -n -c --arg sn "$SKILL_NAME" '{isSkill:true,skillName:$sn}')"
                    ;;
                edit|create|view)
                    FPATH="$(echo "$ARGS_PARSED" | jq -r '.path // empty' 2>/dev/null)"
                    DETAIL="path:$(truncate "$FPATH" 210)"
                    ;;
                grep|glob)
                    PATTERN="$(echo "$ARGS_PARSED" | jq -r '.pattern // empty' 2>/dev/null)"
                    FPATH="$(echo "$ARGS_PARSED" | jq -r '.path // empty' 2>/dev/null)"
                    DETAIL="pattern:\"$(truncate "$PATTERN" 120)\""
                    [ -n "$FPATH" ] && DETAIL="$DETAIL path:$FPATH"
                    ;;
                *)
                    if [ -n "$ARGS_PARSED" ]; then
                        FIRST_KEY="$(echo "$ARGS_PARSED" | jq -r 'keys[0] // empty' 2>/dev/null)"
                        FIRST_VAL="$(echo "$ARGS_PARSED" | jq -r '.[keys[0]] // empty' 2>/dev/null)"
                        [ -n "$FIRST_KEY" ] && [ -n "$FIRST_VAL" ] && DETAIL="$FIRST_KEY:\"$(truncate "$FIRST_VAL" 150)\""
                    fi
                    ;;
            esac

            TOOL_PAD="$(printf '%-18s' "$TOOL_NAME")"
            SUMMARY_LINE="[$TIME_STR] TOOL>     ${TOOL_PAD}| $DETAIL"

            # Build detailed JSON
            DETAILED_JSON="$(echo "$INPUT" | jq -c \
                --arg event "$EVENT" --arg ts "$ISO_STR" \
                '{event:$event,ts:$ts,tsMs:.timestamp,toolName:.toolName}')"
            if [ -n "$ARGS_PARSED" ]; then
                DETAILED_JSON="$(echo "$DETAILED_JSON" | jq -c --argjson args "$ARGS_PARSED" '. + {toolArgs:$args}')"
            else
                DETAILED_JSON="$(echo "$DETAILED_JSON" | jq -c --arg args "$ARGS_RAW" '. + {toolArgsRaw:$args}')"
            fi
            [ -n "$META" ] && DETAILED_JSON="$(echo "$DETAILED_JSON" | jq -c --argjson meta "$META" '. + {meta:$meta}')"
            echo "$DETAILED_JSON" >> "$DETAILED"
            ;;

        postToolUse)
            TOOL_NAME="$(echo "$INPUT" | jq -r '.toolName // empty')"
            ARGS_RAW="$(echo "$INPUT" | jq -r '.toolArgs // empty')"
            ARGS_PARSED="$(parse_tool_args "$ARGS_RAW")" || ARGS_PARSED=""
            RESULT_TYPE="$(echo "$INPUT" | jq -r '.toolResult.resultType // empty')"
            RESULT_TEXT="$(echo "$INPUT" | jq -r '.toolResult.textResultForLlm // empty')"

            case "$RESULT_TYPE" in
                success) STATUS_ICON="✓" ;;
                failure) STATUS_ICON="✗" ;;
                denied)  STATUS_ICON="⛔" ;;
                *)       STATUS_ICON="?" ;;
            esac

            DETAIL=""
            if [ "$TOOL_NAME" = "task" ] && [ -n "$ARGS_PARSED" ]; then
                AGENT_TYPE="$(echo "$ARGS_PARSED" | jq -r '.agent_type // empty' 2>/dev/null)"
                [ -n "$AGENT_TYPE" ] && DETAIL="agent:$AGENT_TYPE"
            fi
            if [ -n "$RESULT_TEXT" ]; then
                PREVIEW="$(truncate "$RESULT_TEXT" 180)"
                [ -n "$DETAIL" ] && DETAIL="$DETAIL "
                DETAIL="${DETAIL}\"$PREVIEW\""
            fi

            TOOL_PAD="$(printf '%-18s' "$TOOL_NAME")"
            STATUS_PAD="$(printf '%-5s' "$STATUS_ICON")"
            SUMMARY_LINE="[$TIME_STR] TOOL<     ${TOOL_PAD}${STATUS_PAD}| $DETAIL"

            # Copy any temp files referenced in the result
            copy_temp_files "$RESULT_TEXT" "$TOOL_NAME" "$LOG_DIR"

            # Build detailed JSON
            DETAILED_JSON="$(echo "$INPUT" | jq -c \
                --arg event "$EVENT" --arg ts "$ISO_STR" \
                '{event:$event,ts:$ts,tsMs:.timestamp,toolName:.toolName}')"
            if [ -n "$ARGS_PARSED" ]; then
                DETAILED_JSON="$(echo "$DETAILED_JSON" | jq -c --argjson args "$ARGS_PARSED" '. + {toolArgs:$args}')"
            else
                DETAILED_JSON="$(echo "$DETAILED_JSON" | jq -c --arg args "$ARGS_RAW" '. + {toolArgsRaw:$args}')"
            fi
            DETAILED_JSON="$(echo "$DETAILED_JSON" | jq -c \
                --arg rt "$RESULT_TYPE" --arg rtxt "$RESULT_TEXT" \
                '. + {result:{type:$rt,text:$rtxt}}')"
            echo "$DETAILED_JSON" >> "$DETAILED"
            ;;

        agentStop)
            SUMMARY_LINE="[$TIME_STR] AGENT<    complete"
            jq -n -c --arg event "$EVENT" --arg ts "$ISO_STR" --arg tsMs "$TS_MS" --arg cwd "$CWD" \
                '{event:$event,ts:$ts,tsMs:($tsMs|tonumber),cwd:$cwd}' >> "$DETAILED"
            ;;

        subagentStop)
            SUMMARY_LINE="[$TIME_STR] SUBAGENT< complete"
            jq -n -c --arg event "$EVENT" --arg ts "$ISO_STR" --arg tsMs "$TS_MS" --arg cwd "$CWD" \
                '{event:$event,ts:$ts,tsMs:($tsMs|tonumber),cwd:$cwd}' >> "$DETAILED"
            ;;

        errorOccurred)
            ERR_MSG="$(echo "$INPUT" | jq -r '.error.message // empty')"
            ERR_NAME="$(echo "$INPUT" | jq -r '.error.name // "UnknownError"')"
            PREVIEW="$(truncate "$ERR_MSG" 180)"
            NAME_PAD="$(printf '%-18s' "${ERR_NAME:-UnknownError}")"
            SUMMARY_LINE="[$TIME_STR] ERROR     ${NAME_PAD}| \"$PREVIEW\""
            echo "$INPUT" | jq -c \
                --arg event "$EVENT" --arg ts "$ISO_STR" \
                '{event:$event,ts:$ts,tsMs:.timestamp,error:.error}' >> "$DETAILED"
            ;;
    esac

    # Write summary line (preToolUse/postToolUse already wrote detailed above)
    [ -n "$SUMMARY_LINE" ] && echo "$SUMMARY_LINE" >> "$SUMMARY"

} 2>/dev/null
exit 0
