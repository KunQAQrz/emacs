#!/usr/bin/env bash
set -euo pipefail  # 严格模式：出错即退出，未定义变量报错

# ==================== 获取脚本所在目录 ====================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ==================== 配置区域（已按要求修改） ====================
DEFAULT_VERSION="30.2"               # 默认Emacs版本
DOWNLOAD_DIR="$SCRIPT_DIR/download"  # 下载目录
EMACS_DIR="$SCRIPT_DIR/emacs"        # 最终Emacs目录：脚本目录/emacs

SOURCE_URL="https://ftp.gnu.org"
#SOURCE_URL="https://mirrors.tuna.tsinghua.edu.cn"
#SOURCE_URL="https://mirrors.ustc.edu.cn"

# ==================== 颜色输出函数 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_color() { if [[ $# -lt 2 ]]; then echo "$1"; else echo -e "$2 $1 ${NC}"; fi; }

# ==================== 使用说明 ====================
usage() {
    cat <<EOF
用法: $0 [选项]

选项:
  -v, --version VERSION    指定Emacs版本（默认: $DEFAULT_VERSION）
  -s, --source-url URL     指定下载源（默认: $SOURCE_URL）
  -h, --help               显示此帮助信息

说明:
  下载目录: $DOWNLOAD_DIR
  安装目录: $EMACS_DIR

示例:
  $0                          # 下载默认版本（$DEFAULT_VERSION）
  $0 -v 29.4                  # 下载Emacs 29.4
  $0 -s https://ftp.gnu.org   # 使用官方源下载
EOF
    exit 0
}

# ==================== 环境检查 ====================
check_environment() {
    print_info "检查运行环境..."
    
    # 检查下载工具（wget或curl）
    if command -v wget &> /dev/null; then
        DOWNLOAD_CMD="wget -c -q --show-progress -O"  # -c: 断点续传, --show-progress: 显示进度, -O: 指定输出文件
    elif command -v curl &> /dev/null; then
        DOWNLOAD_CMD="curl -C - -# -o"                # -C -: 断点续传, -#: 显示进度条, -o: 指定输出文件
    else
        print_error "未找到 wget 或 curl，请先安装其中一个工具！"
        exit 1
    fi
    
    # 检查解压工具
    if ! command -v unzip &> /dev/null; then
        print_error "未找到 unzip 工具！"
        if [[ "$MSYSTEM" == *"MSYS"* || "$MSYSTEM" == *"MINGW"* ]]; then
            print_info "MSYS2环境下请运行: pacman -S unzip"
        fi
        exit 1
    fi
    
    print_info "环境检查通过"
}

# ==================== 解析命令行参数 ====================
parse_arguments() {
    VERSION="$DEFAULT_VERSION"
    local source_url="$SOURCE_URL"
    local mirror_base="${source_url}/gnu/emacs/windows"

    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--version) VERSION="$2"; shift 2 ;;
            -s|--source-url) source_url="$2"; shift 2 ;;
            -h|--help) usage ;;
            *) echo "错误：未知选项 $1"; usage ;;
        esac
    done

    print_info "指定版本: Emacs ${VERSION}"
    print_info "使用下载源: $source_url"

    # 提取主版本号（如 30.2 -> 30）
    MAJOR_VERSION=$(echo "$VERSION" | cut -d. -f1)

    # 构建文件名和URL
    EMACS_FILENAME="emacs-${VERSION}.zip"
    DOWNLOAD_URL="${mirror_base}/emacs-${MAJOR_VERSION}/${EMACS_FILENAME}"
}

# ==================== 清理旧文件 ====================
cleanup_old() {
    print_info "清理旧文件..."
    
    # 删除旧的安装目录（如果存在）
    if [[ -d "$EMACS_DIR" ]]; then
        print_warn "安装目录已存在，将被覆盖！"
        read -p "按 Enter 继续，或 Ctrl+C 取消..."
        rm -rf "$EMACS_DIR"
    fi
}

# ==================== 下载文件 ====================
download_file() {
if [ -f "$DOWNLOAD_DIR/$EMACS_FILENAME" ]; then
    print_info "检测到已存在 ${EMACS_FILENAME}，跳过下载步骤。"
else
    print_info "准备下载 ${EMACS_FILENAME}"
    print_info "下载地址: $DOWNLOAD_URL"
    print_info "保存目录: $DOWNLOAD_DIR"
    
    # 创建下载目录
    mkdir -p "$DOWNLOAD_DIR"
    cd "$DOWNLOAD_DIR"
    
    # 下载文件
    print_info "开始下载..."
    $DOWNLOAD_CMD "$EMACS_FILENAME" "$DOWNLOAD_URL"
    print_info "下载完成: $EMACS_FILENAME"
fi
}

# ==================== 解压文件 ====================
extract_file() {
    print_info "准备解压到: $EMACS_DIR"
    
    # 确保目标目录存在
    mkdir -p "$EMACS_DIR"
    
    # 直接解压到目标目录
    unzip -o -q "$DOWNLOAD_DIR/$EMACS_FILENAME" -d "$EMACS_DIR"
    
    # 检查解压结果
    if [[ ! -f "$EMACS_DIR/bin/runemacs.exe" ]]; then
        # 可能是嵌套目录结构，尝试查找实际的Emacs目录
        EMACS_VERSIONED_DIR=$(find "$EMACS_DIR" -maxdepth 1 -type d -name "emacs-*" | head -n 1)
        
        if [[ -n "$EMACS_VERSIONED_DIR" && -f "$EMACS_VERSIONED_DIR/bin/runemacs.exe" ]]; then
            # 将内容移动到上层目录
            print_info "找到嵌套的Emacs目录，正在整理..."
            cp -r "$EMACS_VERSIONED_DIR/"* "$EMACS_DIR/"
            rm -rf "$EMACS_VERSIONED_DIR"
        else
            print_error "解压后未找到Emacs可执行文件！"
            print_error "请检查zip文件结构，确保是有效的Emacs安装包"
            print_info "解压目录内容："
            find "$EMACS_DIR" -type f | head -n 20
            exit 1
        fi
    fi
    
    print_info "解压完成！目录: $EMACS_DIR"
}

# ==================== 完成提示 ====================
show_completion() {
    print_color ""
    print_color "============================================="
    print_color "✅ Emacs 安装成功！" ${GREEN}
    print_color "============================================="
    print_color "📦 版本: Emacs ${VERSION}"
    print_color "📂 脚本目录: $SCRIPT_DIR"
    print_color "📂 安装目录: $EMACS_DIR"
    print_color "🚀 启动程序: $EMACS_DIR/bin/runemacs.exe"
    print_color "============================================="
}

# ==================== 主函数 ====================
main() {
    check_environment
    parse_arguments "$@"
    cleanup_old
    download_file
    extract_file
    show_completion
}

# 执行主函数
main "$@"