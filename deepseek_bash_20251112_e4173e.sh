#!/bin/bash

# RexChat - Philippine-Wide Online Chat with Posts Feature
# Instant messaging, social posts, scrollable chat

# Colors
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
PURPLE='\033[1;35m'
ORANGE='\033[1;33m'
MAGENTA='\033[1;35m'
NC='\033[0m'

# Configuration
USER_FILE="rexchat_users.txt"
CONFIG_FILE="rexchat_config.txt"
LOG_FILE="rexchat.log"
CHAT_FILE="rexchat_messages.txt"
ONLINE_FILE="rexchat_online.txt"
POSTS_FILE="rexchat_posts.txt"

# Create files
touch "$USER_FILE" "$CONFIG_FILE" "$LOG_FILE" "$CHAT_FILE" "$ONLINE_FILE" "$POSTS_FILE"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║                REXCHAT PHILIPPINES          ║"
    echo "║      Instant Chat + Social Posts           ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${YELLOW}    🌏 Chat + Posts - All in One!${NC}"
    echo -e "${GREEN}         Futuristic Termux Social App${NC}"
    echo "=============================================="
}

# Check internet connection
check_internet() {
    if ping -c 1 8.8.8.8 &> /dev/null; then
        return 0
    else
        echo -e "${RED}❌ No internet connection!${NC}"
        return 1
    fi
}

# Install required packages
install_dependencies() {
    echo -e "${YELLOW}Checking dependencies...${NC}"
    
    if ! command -v curl &> /dev/null; then
        echo -e "${YELLOW}Installing curl...${NC}"
        pkg update -y && pkg install -y curl
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}Installing jq...${NC}"
        pkg install -y jq
    fi
    
    echo -e "${GREEN}✅ Dependencies ready!${NC}"
}

# User registration with AUTO-LOGIN
register_user() {
    echo -e "\n${YELLOW}=== CREATE PHILIPPINE ACCOUNT ===${NC}"
    read -p "🇵🇭 Choose your nickname: " nickname
    
    # Check if nickname exists locally
    if grep -q "^$nickname:" "$USER_FILE"; then
        echo -e "${RED}❌ Nickname already taken!${NC}"
        return 1
    fi
    
    read -s -p "🔒 Enter password: " password
    echo
    read -s -p "🔒 Confirm password: " password2
    echo
    
    if [ "$password" != "$password2" ]; then
        echo -e "${RED}❌ Passwords don't match!${NC}"
        return 1
    fi
    
    if [ -z "$nickname" ] || [ -z "$password" ]; then
        echo -e "${RED}❌ Nickname and password required!${NC}"
        return 1
    fi
    
    # Add location info
    echo -e "${CYAN}📍 Select your region:${NC}"
    echo "1. Metro Manila"
    echo "2. Luzon"
    echo "3. Visayas" 
    echo "4. Mindanao"
    echo "5. Other"
    read -p "Choose [1-5]: " region_choice
    
    case $region_choice in
        1) region="Metro Manila" ;;
        2) region="Luzon" ;;
        3) region="Visayas" ;;
        4) region="Mindanao" ;;
        5) region="Other" ;;
        *) region="Philippines" ;;
    esac
    
    password_hash=$(echo -n "$password" | base64)
    echo "$nickname:$password_hash:$region:$(date '+%Y-%m-%d')" >> "$USER_FILE"
    
    # AUTO-LOGIN after registration
    echo "$nickname" > "rexchat_current_user.txt"
    echo "$region" > "rexchat_current_region.txt"
    
    echo -e "${GREEN}✅ Account created! From: $region${NC}"
    echo -e "${YELLOW}✅ Automatically logged in as $nickname!${NC}"
    log "New user: $nickname from $region"
    return 0
}

# User login
login_user() {
    echo -e "\n${YELLOW}=== LOGIN TO REXCHAT PH ===${NC}"
    read -p "🇵🇭 Nickname: " nickname
    read -s -p "🔒 Password: " password
    echo
    
    password_hash=$(echo -n "$password" | base64)
    if grep -q "^$nickname:$password_hash:" "$USER_FILE"; then
        user_data=$(grep "^$nickname:$password_hash:" "$USER_FILE")
        region=$(echo "$user_data" | cut -d: -f3)
        
        echo "$nickname" > "rexchat_current_user.txt"
        echo "$region" > "rexchat_current_region.txt"
        
        echo -e "${GREEN}✅ Login successful!${NC}"
        echo -e "${CYAN}📍 Location: $region${NC}"
        log "User login: $nickname from $region"
        return 0
    else
        echo -e "${RED}❌ Invalid login!${NC}"
        return 1
    fi
}

# POSTS FEATURE - Facebook-like posts in Termux
create_post() {
    local nickname="$1"
    local region="$2"
    
    echo -e "\n${CYAN}📝 CREATE NEW POST${NC}"
    echo -e "${YELLOW}What's on your mind, $nickname?${NC}"
    echo -e "${GREEN}(Type your post content - Press Enter twice to finish)${NC}"
    echo ""
    
    # Multi-line post input
    local post_content=""
    local line=""
    local line_count=0
    
    while IFS= read -r line; do
        if [ -z "$line" ] && [ $line_count -gt 0 ]; then
            break
        fi
        if [ -n "$line" ]; then
            if [ -z "$post_content" ]; then
                post_content="$line"
            else
                post_content="$post_content\n$line"
            fi
            line_count=$((line_count + 1))
        fi
    done
    
    if [ -z "$post_content" ]; then
        echo -e "${RED}❌ Post cannot be empty!${NC}"
        return 1
    fi
    
    # Save post with timestamp
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local post_id=$(date +%s)
    
    echo "$post_id|$timestamp|$nickname|$region|$post_content" >> "$POSTS_FILE"
    
    echo -e "${GREEN}✅ Post published successfully!${NC}"
    echo -e "${YELLOW}📱 Your post is now visible to all RexChat users${NC}"
}

# Display posts in Facebook-like card format
view_posts() {
    echo -e "\n${CYAN}📱 REXCHAT POSTS FEED${NC}"
    echo -e "${YELLOW}Latest posts from RexChat community:${NC}"
    echo ""
    
    if [ ! -s "$POSTS_FILE" ]; then
        echo -e "${RED}No posts yet. Be the first to post!${NC}"
        echo -e "${YELLOW}Use 'Create Post' from main menu${NC}"
        return
    fi
    
    # Read posts in reverse order (newest first)
    local post_count=0
    tac "$POSTS_FILE" | while IFS='|' read -r post_id timestamp nickname region post_content; do
        if [ -n "$post_id" ]; then
            post_count=$((post_count + 1))
            
            # Facebook-like post card
            echo -e "${CYAN}┌──────────────────────────────────────────┐${NC}"
            echo -e "${BLUE}👤 $nickname${NC}"
            echo -e "${YELLOW}📍 $region${NC}"
            echo -e "${PURPLE}🕒 $timestamp${NC}"
            echo -e "${CYAN}├──────────────────────────────────────────┤${NC}"
            echo -e "${GREEN}$post_content${NC}" | sed 's/\\n/\n/g'
            echo -e "${CYAN}└──────────────────────────────────────────┘${NC}"
            echo ""
            
            # Show only last 10 posts to avoid overflow
            if [ $post_count -ge 10 ]; then
                echo -e "${YELLOW}📜 Showing latest 10 posts. Scroll up to see more.${NC}"
                break
            fi
        fi
    done
    
    if [ $post_count -eq 0 ]; then
        echo -e "${RED}No posts found.${NC}"
    fi
}

# SCROLLABLE CHAT ROOM with older messages
start_scrollable_chat() {
    local nickname="$1"
    local region="$2"
    
    if ! check_internet; then
        echo -e "${RED}❌ Internet required for nationwide chat!${NC}"
        echo -e "${YELLOW}Please enable mobile data or WiFi${NC}"
        return 1
    fi
    
    # Add JOIN message
    timestamp=$(date '+%H:%M:%S')
    echo "[$timestamp] 🟢 $nickname joined the chatroom" >> "$CHAT_FILE"
    
    # Add to online users
    echo "$nickname" >> "$ONLINE_FILE"
    
    echo -e "${GREEN}🚀 Entering scrollable chat room...${NC}"
    sleep 2
    
    # Display chat header
    show_chat_header() {
        clear
        echo -e "${CYAN}"
        echo "╔══════════════════════════════════════════════╗"
        echo "║              SCROLLABLE CHAT ROOM           ║"
        echo "║         ↑ Scroll Up - ↓ Scroll Down         ║"
        echo "╚══════════════════════════════════════════════╝"
        echo -e "${NC}"
        echo -e "${GREEN}👤 You: $nickname | 📍 $region${NC}"
        echo -e "${YELLOW}💬 Scroll to see older messages${NC}"
        echo "──────────────────────────────────────────────"
    }
    
    # Display messages with COLOR and SCROLLING info
    display_scrollable_messages() {
        local total_lines=$(wc -l < "$CHAT_FILE" 2>/dev/null || echo 0)
        local display_lines=20  # Show last 20 lines initially
        
        if [ $total_lines -gt $display_lines ]; then
            echo -e "${YELLOW}📜 Showing last $display_lines messages ($total_lines total)${NC}"
            echo -e "${GREEN}⬆️  Scroll up to see older messages${NC}"
            echo "──────────────────────────────────────────────"
            # Show last 'display_lines' messages
            tail -n $display_lines "$CHAT_FILE" | while IFS= read -r line; do
                colorize_message "$line"
            done
        else
            # Show all messages if less than display_lines
            if [ -f "$CHAT_FILE" ] && [ -s "$CHAT_FILE" ]; then
                cat "$CHAT_FILE" | while IFS= read -r line; do
                    colorize_message "$line"
                done
            else
                echo "💬 No messages yet. Start the conversation!"
            fi
        fi
    }
    
    # Colorize individual messages
    colorize_message() {
        local line="$1"
        if [[ "$line" =~ .*"joined the chatroom" ]]; then
            # Join messages in GREEN
            echo -e "${GREEN}$line${NC}"
        elif [[ "$line" =~ .*"left the chatroom" ]]; then
            # Leave messages in RED
            echo -e "${RED}$line${NC}"
        elif [[ "$line" =~ .*"$nickname".* ]]; then
            # MY messages in BLUE
            echo -e "${BLUE}$line${NC}"
        else
            # OTHER users' messages in YELLOW
            echo -e "${YELLOW}$line${NC}"
        fi
    }
    
    # Show full chat history with less command
    show_full_chat_history() {
        echo -e "${CYAN}📜 FULL CHAT HISTORY - Press 'q' to return${NC}"
        if [ -f "$CHAT_FILE" ] && [ -s "$CHAT_FILE" ]; then
            less -R "$CHAT_FILE"
        else
            echo -e "${RED}No chat history found${NC}"
            read -p "Press Enter to continue..."
        fi
    }
    
    # Send instant message (NO DELAY)
    send_instant_message() {
        local msg="$1"
        timestamp=$(date '+%H:%M:%S')
        
        # INSTANT send - no delays
        echo "[$timestamp] $nickname: $msg" >> "$CHAT_FILE"
        echo -e "${GREEN}✅ Message sent instantly!${NC}"
    }
    
    # Show online users
    show_online_users() {
        echo -e "\n${CYAN}👥 Online Now:${NC}"
        echo "──────────────────────────────────────────────"
        if [ -f "$ONLINE_FILE" ] && [ -s "$ONLINE_FILE" ]; then
            cat "$ONLINE_FILE" | while read -r user; do
                if [ "$user" == "$nickname" ]; then
                    echo -e "${GREEN}🟢 $user (You)${NC}"
                else
                    echo -e "${YELLOW}🟢 $user${NC}"
                fi
            done
        else
            echo "No users online"
        fi
        echo "──────────────────────────────────────────────"
    }
    
    # Cleanup when leaving chat
    cleanup_chat() {
        # Remove from online users
        if [ -f "$ONLINE_FILE" ]; then
            grep -v "^$nickname$" "$ONLINE_FILE" > "${ONLINE_FILE}.tmp"
            mv "${ONLINE_FILE}.tmp" "$ONLINE_FILE"
        fi
        
        # Add LEAVE message
        timestamp=$(date '+%H:%M:%S')
        echo "[$timestamp] 🔴 $nickname left the chatroom" >> "$CHAT_FILE"
        
        echo -e "${YELLOW}👋 You left the chatroom${NC}"
    }
    
    # Set trap for cleanup
    trap cleanup_chat EXIT
    
    # Enhanced chat loop with SCROLLING options
    scrollable_chat_loop() {
        local last_size=0
        local current_size=0
        
        while true; do
            # Check for new messages instantly
            if [ -f "$CHAT_FILE" ]; then
                current_size=$(stat -c %s "$CHAT_FILE" 2>/dev/null || echo 0)
            fi
            
            # Only refresh if there are new messages
            if [ "$current_size" -ne "$last_size" ]; then
                last_size=$current_size
                show_chat_header
                display_scrollable_messages
                echo "──────────────────────────────────────────────"
                show_online_users
                echo -e "${GREEN}💬 Commands: /exit /history /users /clear /help${NC}"
                echo -n "➤ "
            fi
            
            # Non-blocking read for instant input
            if read -t 0.5 -r message; then
                case "$message" in
                    "/exit")
                        echo -e "${YELLOW}Leaving chatroom...${NC}"
                        break
                        ;;
                    "/history")
                        show_full_chat_history
                        last_size=0  # Force refresh after returning from history
                        ;;
                    "/users")
                        show_online_users
                        read -p "Press Enter to continue..."
                        ;;
                    "/clear")
                        clear
                        ;;
                    "/help")
                        echo -e "${CYAN}📋 Scrollable Chat Commands:${NC}"
                        echo "/exit     - Leave chatroom"
                        echo "/history  - View full chat history (scrollable)"
                        echo "/users    - Show online users"
                        echo "/clear    - Clear screen"
                        echo "/help     - Show this help"
                        read -p "Press Enter to continue..."
                        ;;
                    "")
                        # Empty message, do nothing
                        ;;
                    *)
                        send_instant_message "$message"
                        # Instant refresh after sending
                        last_size=0
                        ;;
                esac
            fi
        done
    }
    
    # Start the scrollable chat
    scrollable_chat_loop
}

# Setup chat system
setup_chat_system() {
    echo -e "${YELLOW}Setting up chat and posts system...${NC}"
    
    # Create chat file with welcome message
    if [ ! -s "$CHAT_FILE" ]; then
        timestamp=$(date '+%H:%M:%S')
        echo "[$timestamp] 🎉 Welcome to RexChat Philippines!" > "$CHAT_FILE"
        echo "[$timestamp] 💬 Instant messaging + Social Posts!" >> "$CHAT_FILE"
        echo "[$timestamp] 🌏 Chat with Filipinos nationwide!" >> "$CHAT_FILE"
    fi
    
    # Create sample post if empty
    if [ ! -s "$POSTS_FILE" ]; then
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "$(date +%s)|$timestamp|System|Philippines|Welcome to RexChat Posts! Share your thoughts with the community. This is like Facebook but in Termux! 📱" >> "$POSTS_FILE"
    fi
    
    echo -e "${GREEN}✅ Chat + Posts system ready!${NC}"
}

# Main menu with POSTS feature
main_menu() {
    while true; do
        show_banner
        
        # Check if user is logged in
        if [ -f "rexchat_current_user.txt" ]; then
            nickname=$(cat "rexchat_current_user.txt")
            region=$(cat "rexchat_current_region.txt")
            echo -e "${GREEN}✅ Logged in as: $nickname from $region${NC}"
        else
            echo -e "${YELLOW}⚠️  Not logged in${NC}"
        fi
        
        if ! check_internet; then
            echo -e "${RED}⚠️  OFFLINE - Internet required${NC}"
        else
            echo -e "${GREEN}✅ ONLINE - All features ready${NC}"
        fi
        
        echo ""
        echo -e "${GREEN}Main Menu:${NC}"
        echo "1. 🚀 Scrollable Chat Room"
        echo "2. 📝 Create Post (Facebook-style)"
        echo "3. 📱 View Posts Feed"
        echo "4. 👤 Create Account (Auto-Login)"
        echo "5. 🔐 Login"
        echo "6. 👥 View Online Users"
        echo "7. 📖 How to Use"
        echo "8. 🚪 Exit"
        echo ""
        
        read -p "Choose [1-8]: " choice
        
        case $choice in
            1)
                if [ -f "rexchat_current_user.txt" ]; then
                    nickname=$(cat "rexchat_current_user.txt")
                    region=$(cat "rexchat_current_region.txt")
                    start_scrollable_chat "$nickname" "$region"
                else
                    echo -e "${RED}Please login or create account first!${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            2)
                if [ -f "rexchat_current_user.txt" ]; then
                    nickname=$(cat "rexchat_current_user.txt")
                    region=$(cat "rexchat_current_region.txt")
                    create_post "$nickname" "$region"
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Please login first to create posts!${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            3)
                view_posts
                read -p "Press Enter to continue..."
                ;;
            4)
                if register_user; then
                    echo -e "${GREEN}✅ Ready to chat and post!${NC}"
                    read -p "Press Enter to continue..."
                else
                    read -p "Press Enter to continue..."
                fi
                ;;
            5)
                if login_user; then
                    echo -e "${GREEN}✅ Ready to chat and post!${NC}"
                    read -p "Press Enter to continue..."
                else
                    read -p "Press Enter to continue..."
                fi
                ;;
            6)
                echo -e "\n${CYAN}👥 Currently Online:${NC}"
                echo "──────────────────────────────────────────────"
                if [ -f "$ONLINE_FILE" ] && [ -s "$ONLINE_FILE" ]; then
                    cat "$ONLINE_FILE"
                else
                    echo "No users online right now"
                fi
                echo "──────────────────────────────────────────────"
                read -p "Press Enter to continue..."
                ;;
            7)
                show_tutorial
                ;;
            8)
                # Add leave message if user was in chat
                if [ -f "rexchat_current_user.txt" ]; then
                    nickname=$(cat "rexchat_current_user.txt")
                    # Remove from online users
                    if [ -f "$ONLINE_FILE" ]; then
                        grep -v "^$nickname$" "$ONLINE_FILE" > "${ONLINE_FILE}.tmp"
                        mv "${ONLINE_FILE}.tmp" "$ONLINE_FILE"
                    fi
                fi
                echo -e "${GREEN}Salamat for using RexChat Philippines! 🇵🇭${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice!${NC}"
                ;;
        esac
    done
}

# Enhanced Tutorial with Posts feature
show_tutorial() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║           FUTURISTIC FEATURES GUIDE         ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${GREEN}🚀 REXCHAT 2.0 - ALL NEW FEATURES:${NC}"
    echo ""
    echo -e "${YELLOW}📝 SOCIAL POSTS SYSTEM:${NC}"
    echo "• Create Facebook-style posts"
    echo "• Card-based post display"
    echo "• Multi-line post support"
    echo "• See posts from all users"
    echo "• Timestamp and user info"
    echo ""
    echo -e "${YELLOW}📜 SCROLLABLE CHAT ROOM:${NC}"
    echo "• View older messages with /history"
    echo "• Scroll up/down in chat history"
    echo "• Never miss any conversation"
    echo "• Full chat archive access"
    echo ""
    echo -e "${YELLOW}🎨 ENHANCED INTERFACE:${NC}"
    echo "• Beautiful post cards"
    echo "• Color-coded messages"
    echo "• Professional layout"
    echo "• Easy navigation"
    echo ""
    echo -e "${YELLOW}💬 CHAT COMMANDS:${NC}"
    echo "/history - View full scrollable chat history"
    echo "/exit    - Leave chatroom"
    echo "/users   - Show online users"
    echo "/clear   - Clear screen"
    echo ""
    echo -e "${RED}⚠️  IMPORTANT:${NC}"
    echo "• Internet required for all features"
    echo "• Posts are visible to all users"
    echo "• Chat history is saved locally"
    echo "• Works nationwide in Philippines"
    echo ""
    
    read -p "Press Enter to continue..."
}

# Initialize
initialize_app() {
    echo -e "${YELLOW}Initializing RexChat with Posts Feature...${NC}"
    
    install_dependencies
    setup_chat_system
    
    echo -e "${GREEN}✅ RexChat 2.0 with Posts Ready!${NC}"
    sleep 2
}

# Start application
initialize_app
main_menu