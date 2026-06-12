#!/usr/bin/env bash

# ╔══════════════════════════════════════════════════════╗
# ║            NODE ECOSYSTEM DOCTOR  v1.0.0             ║
# ║    Diagnóstico · Sugestões · Correção Interativa     ║
# ║    ---------------------------------------------     ║
# ║    Autor: Roberto Godoy · 2026                       ║
# ╚══════════════════════════════════════════════════════╝

# ---------- Flags ----------
AUTO_FIX=false
MINIMAL=false
JSON_OUTPUT=false
LOG_ENABLED=true

for arg in "$@"; do
  case "$arg" in
    --auto-fix)   AUTO_FIX=true ;;
    --minimal)    MINIMAL=true ;;
    --json)       JSON_OUTPUT=true; MINIMAL=true ;;
    --no-log)     LOG_ENABLED=false ;;
    --help|-h)
      echo "Uso: $0 [--auto-fix] [--minimal] [--json] [--no-log]"
      echo ""
      echo "  --auto-fix   Corrige problemas automaticamente (sem perguntas)"
      echo "  --minimal    Saída compacta, sem interação"
      echo "  --json       Output estruturado em JSON (implica --minimal)"
      echo "  --no-log     Não salva log em /tmp/"
      exit 0
      ;;
  esac
done

# ---------- Colors (desativadas em modo JSON) ----------
if [ "$JSON_OUTPUT" = false ]; then
  RED="\033[0;31m"
  GREEN="\033[0;32m"
  YELLOW="\033[1;33m"
  BLUE="\033[0;34m"
  CYAN="\033[0;36m"
  MAGENTA="\033[1;35m"
  GRAY="\033[0;90m"
  BOLD="\033[1m"
  NC="\033[0m"
else
  RED="" GREEN="" YELLOW="" BLUE="" CYAN="" MAGENTA="" GRAY="" BOLD="" NC=""
fi

# ---------- Log setup ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "$LOG_DIR"

LOG_FILE="${LOG_DIR}/node-doctor-$(date +%Y%m%d-%H%M%S).log"

log() {
  if [ "$LOG_ENABLED" = true ] && [ "$JSON_OUTPUT" = false ]; then
    echo -e "$1" >> "$LOG_FILE" 2>/dev/null
  fi
}

# Captura tudo no log
if [ "$LOG_ENABLED" = true ] && [ "$JSON_OUTPUT" = false ]; then
  exec > >(tee -a "$LOG_FILE") 2>&1
fi

# ---------- Cleanup no exit ----------
_SPINNER_PID=""

cleanup() {
  if [ -n "$_SPINNER_PID" ]; then
    kill "$_SPINNER_PID" 2>/dev/null
    wait "$_SPINNER_PID" 2>/dev/null
  fi
  tput cnorm 2>/dev/null  # restaura cursor
  echo ""
}

trap cleanup EXIT INT TERM

# ---------- Helpers ----------
print_banner() {
  if [ "$MINIMAL" = true ]; then return; fi
  echo -e "${CYAN}"
  echo "  ╔══════════════════════════════════════════════════════╗"
  echo "  ║          NODE ECOSYSTEM DOCTOR  v1.0.0               ║"
  echo "  ║    Diagnóstico · Sugestões · Correção Interativa     ║"
  echo "  ║    ---------------------------------------------     ║"
  echo "  ║    Autor: Roberto Godoy · 2026                       ║"
  echo "  ╚══════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

print_section() {
  if [ "$MINIMAL" = true ]; then return; fi
  echo ""
  echo -e "${GRAY}  ╔══ ${CYAN}${BOLD}$1${NC}${GRAY} $(printf '═%.0s' $(seq 1 $((48 - ${#1}))))╗${NC}"
  echo ""
}

ok()   { echo -e "  ${GREEN}✔${NC}  $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
fail() { echo -e "  ${RED}✘${NC}  $1"; }
info() { echo -e "  ${MAGENTA}➜${NC}  ${GRAY}$1${NC}"; }
cmd()  { echo -e "     ${GRAY}\$${NC} ${GREEN}$1${NC}"; }

# ---------- Spinner ----------
spinner_start() {
  local msg="$1"
  if [ "$MINIMAL" = true ]; then return; fi
  tput civis 2>/dev/null  # esconde cursor
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  (
    local i=0
    while true; do
      printf "\r  ${CYAN}%s${NC}  %s " "${frames[$i]}" "$msg"
      i=$(( (i + 1) % 10 ))
      sleep 0.08
    done
  ) &
  _SPINNER_PID=$!
}

spinner_stop() {
  if [ -n "$_SPINNER_PID" ]; then
    kill "$_SPINNER_PID" 2>/dev/null
    wait "$_SPINNER_PID" 2>/dev/null
    _SPINNER_PID=""
    tput cnorm 2>/dev/null
    printf "\r\033[K"  # limpa linha
  fi
}

# ---------- Barra de progresso colorida ----------
draw_bar() {
  local label=$1
  local value=$2

  local width=35
  local filled=$(( value * width / 100 ))
  local empty=$(( width - filled ))

  local color
  if (( value >= 90 )); then
    color=$GREEN
  elif (( value >= 60 )); then
    color=$YELLOW
  else
    color=$RED
  fi

  printf "  %-10s ${GRAY}[${NC}${color}" "$label"

  for ((i=0; i<filled; i++)); do
    printf "█"
  done

  printf "${NC}${GRAY}"

  for ((i=0; i<empty; i++)); do
    printf "░"
  done

  printf "${NC}${GRAY}]${NC} ${color}%3d%%${NC}\n" "$value"
}

# ---------- Correção interativa / auto ----------
fix_component() {
  local component=$1
  local command=$2

  if [ "$AUTO_FIX" = true ]; then
    echo ""
    info "Auto-fix: ${component}..."
    if eval "$command"; then
      ok "${component} corrigido com sucesso."
    else
      warn "Falha ao corrigir ${component}. Verifique permissões."
    fi
    return
  fi

  if [ "$MINIMAL" = true ]; then return; fi

  echo ""
  read -rp "  Deseja corrigir ${component}? (s/n): " choice
  case "$choice" in
    s|S|y|Y)
      echo ""
      info "Executando correção..."
      cmd "$command"
      echo ""
      if eval "$command"; then
        ok "${component} corrigido com sucesso."
      else
        warn "Falha ao corrigir ${component}."
      fi
      ;;
    *) warn "Correção ignorada para ${component}." ;;
  esac
}

# ---------- Scores ----------
declare -A SCORE
declare -A SCORE_NOTE
declare -A SCORE_VERSION

SCORE[NODE]=0; SCORE[NPM]=0; SCORE[NVM]=0
SCORE[YARN]=0; SCORE[PNPM]=0; SCORE[BUN]=0
SCORE[NETWORK]=0; SCORE[CACHE]=0

# ================================================================
#  START
# ================================================================

clear
print_banner

# ----------------------------------------------------------------
#  NODE
# ----------------------------------------------------------------
print_section "NODE.JS"

if command -v node >/dev/null 2>&1; then
  NODE_VERSION=$(node -v)
  SCORE_VERSION[NODE]=$NODE_VERSION
  MAJOR=$(echo "$NODE_VERSION" | sed 's/v//' | cut -d '.' -f1)
  ok "Node instalado: ${BOLD}${NODE_VERSION}${NC}"

  if   (( MAJOR >= 22 )); then
    SCORE[NODE]=100
    SCORE_NOTE[NODE]="ok"
  elif (( MAJOR >= 18 )); then
    SCORE[NODE]=80
    SCORE_NOTE[NODE]="abaixo do ideal (recomendado ≥ v22 LTS)"
    warn "Versão do Node abaixo do ideal."
    info "Recomendado: Node v22 LTS"
    fix_component "Node v22 via NVM" \
      "source \"\$HOME/.nvm/nvm.sh\" && nvm install 22 && nvm use 22 && nvm alias default 22"
  else
    SCORE[NODE]=40
    SCORE_NOTE[NODE]="versão muito antiga (recomendado ≥ v22 LTS)"
    fail "Node desatualizado (v${MAJOR}). Versões abaixo de 18 não recebem mais suporte."
    fix_component "Node v22 via NVM" \
      "source \"\$HOME/.nvm/nvm.sh\" && nvm install 22 && nvm use 22 && nvm alias default 22"
  fi

  # Detecta .nvmrc ou .node-version no diretório atual
  if [ -f ".nvmrc" ] || [ -f ".node-version" ]; then
    NVMRC_FILE=".nvmrc"
    [ -f ".node-version" ] && NVMRC_FILE=".node-version"
    REQUIRED_VERSION=$(cat "$NVMRC_FILE" | tr -d '[:space:]')
    CURRENT_MAJOR=$(echo "$NODE_VERSION" | sed 's/v//' | cut -d '.' -f1)
    REQUIRED_MAJOR=$(echo "$REQUIRED_VERSION" | sed 's/v//' | cut -d '.' -f1)
    if [ "$CURRENT_MAJOR" != "$REQUIRED_MAJOR" ]; then
      warn "${NVMRC_FILE} detectado: requer Node ${BOLD}${REQUIRED_VERSION}${NC}, ativo é ${BOLD}${NODE_VERSION}${NC}"
      info "Execute: nvm use"
    else
      ok "${NVMRC_FILE} compatível com versão ativa."
    fi
  fi
else
  fail "Node NÃO está instalado."
  SCORE[NODE]=0
  SCORE_NOTE[NODE]="não instalado"
  fix_component "Node + NVM" \
    "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash && source \"\$HOME/.nvm/nvm.sh\" && nvm install 22"
fi

# ----------------------------------------------------------------
#  NPM
# ----------------------------------------------------------------
print_section "NPM"

if command -v npm >/dev/null 2>&1; then
  NPM_VERSION=$(npm -v)
  SCORE_VERSION[NPM]="v$NPM_VERSION"
  NPM_MAJOR=$(echo "$NPM_VERSION" | cut -d '.' -f1)
  ok "NPM instalado: ${BOLD}v${NPM_VERSION}${NC}"

  if   (( NPM_MAJOR >= 10 )); then
    SCORE[NPM]=100
    SCORE_NOTE[NPM]="ok"
  else
    SCORE[NPM]=70
    SCORE_NOTE[NPM]="desatualizado (recomendado ≥ v10)"
    warn "NPM desatualizado."
    fix_component "NPM" "npm install -g npm@latest"
  fi

  # Pacotes globais desatualizados
  if [ "$MINIMAL" = false ]; then
    info "Verificando pacotes globais desatualizados..."
    OUTDATED=$(npm outdated -g --parseable 2>/dev/null | wc -l | tr -d ' ')
    if (( OUTDATED > 0 )); then
      warn "${BOLD}${OUTDATED}${NC} pacote(s) global(is) desatualizado(s)."
      info "Execute: npm update -g"
    else
      ok "Todos os pacotes globais estão atualizados."
    fi
  fi
else
  fail "NPM não encontrado."
  SCORE[NPM]=0
  SCORE_NOTE[NPM]="não instalado"
fi

# ----------------------------------------------------------------
#  NVM
# ----------------------------------------------------------------
print_section "NVM"

NVM_LOADED=false

if [ -s "$HOME/.nvm/nvm.sh" ]; then
  # shellcheck disable=SC1090
  source "$HOME/.nvm/nvm.sh"
  NVM_VERSION=$(nvm --version 2>/dev/null)
  SCORE_VERSION[NVM]="v$NVM_VERSION"
  ok "NVM instalado: ${BOLD}v${NVM_VERSION}${NC}"
  SCORE[NVM]=100
  SCORE_NOTE[NVM]="ok"
  NVM_LOADED=true

  # Lista versões instaladas
  if [ "$MINIMAL" = false ]; then
    NVM_LIST=$(nvm ls --no-colors 2>/dev/null | grep -E "v[0-9]+" | head -5)
    if [ -n "$NVM_LIST" ]; then
      info "Versões instaladas via NVM:"
      echo "$NVM_LIST" | while IFS= read -r line; do
        echo -e "     ${GRAY}${line}${NC}"
      done
    fi
  fi
else
  warn "NVM não encontrado."
  SCORE[NVM]=40
  SCORE_NOTE[NVM]="não instalado"

  # Verifica alternativas
  if command -v fnm >/dev/null 2>&1; then
    FNM_VERSION=$(fnm --version 2>/dev/null)
    ok "fnm detectado como alternativa: ${BOLD}${FNM_VERSION}${NC}"
    SCORE[NVM]=90
    SCORE_NOTE[NVM]="fnm em uso (${FNM_VERSION})"
  elif command -v volta >/dev/null 2>&1; then
    VOLTA_VERSION=$(volta --version 2>/dev/null)
    ok "volta detectado como alternativa: ${BOLD}v${VOLTA_VERSION}${NC}"
    SCORE[NVM]=90
    SCORE_NOTE[NVM]="volta em uso (v${VOLTA_VERSION})"
  else
    info "Alternativas modernas ao NVM: fnm (Rust, rápido) ou volta"
    fix_component "NVM" \
      "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash"
  fi
fi

# ----------------------------------------------------------------
#  YARN
# ----------------------------------------------------------------
print_section "YARN"

if command -v yarn >/dev/null 2>&1; then
  YARN_VERSION=$(yarn -v 2>/dev/null)
  SCORE_VERSION[YARN]="v$YARN_VERSION"
  ok "Yarn instalado: ${BOLD}v${YARN_VERSION}${NC}"
  SCORE[YARN]=100
  SCORE_NOTE[YARN]="ok"
else
  warn "Yarn não instalado."
  SCORE[YARN]=0
  SCORE_NOTE[YARN]="não instalado"
  info "Necessário para projetos legacy React/Monorepo com Yarn Workspaces."
  fix_component "Yarn" "npm install -g yarn"
fi

# ----------------------------------------------------------------
#  PNPM
# ----------------------------------------------------------------
print_section "PNPM"

if command -v pnpm >/dev/null 2>&1; then
  PNPM_VERSION=$(pnpm -v 2>/dev/null)
  SCORE_VERSION[PNPM]="v$PNPM_VERSION"
  ok "PNPM instalado: ${BOLD}v${PNPM_VERSION}${NC}"
  SCORE[PNPM]=100
  SCORE_NOTE[PNPM]="ok"
else
  warn "PNPM não instalado."
  SCORE[PNPM]=0
  SCORE_NOTE[PNPM]="não instalado"
  info "PNPM usa hard links: muito mais rápido e economiza disco."
  fix_component "PNPM" "npm install -g pnpm"
fi

# ----------------------------------------------------------------
#  BUN
# ----------------------------------------------------------------
print_section "BUN"

if command -v bun >/dev/null 2>&1; then
  BUN_VERSION=$(bun --version 2>/dev/null)
  SCORE_VERSION[BUN]="v$BUN_VERSION"
  ok "Bun instalado: ${BOLD}v${BUN_VERSION}${NC}"
  SCORE[BUN]=100
  SCORE_NOTE[BUN]="ok"
else
  warn "Bun não instalado."
  SCORE[BUN]=0
  SCORE_NOTE[BUN]="não instalado"
  info "Bun: runtime + bundler + test runner ultra-rápido (alternativa ao Node)."
  fix_component "Bun" \
    "curl -fsSL https://bun.sh/install | bash"
fi

# ----------------------------------------------------------------
#  CONECTIVIDADE
# ----------------------------------------------------------------
print_section "CONECTIVIDADE"

spinner_start "Testando registry.npmjs.org..."
sleep 0.5

if ping -c 1 -W 3 registry.npmjs.org >/dev/null 2>&1; then
  spinner_stop
  ok "registry.npmjs.org acessível."
  SCORE[NETWORK]=100
  SCORE_NOTE[NETWORK]="ok"
else
  spinner_stop
  fail "Falha ao acessar registry.npmjs.org."
  SCORE[NETWORK]=20
  SCORE_NOTE[NETWORK]="sem acesso ao registry"

  if [ "$MINIMAL" = false ]; then
    warn "Possíveis causas:"
    echo -e "     ${GRAY}• Firewall corporativo"
    echo    "     • Proxy ou VPN ativa"
    echo    "     • DNS bloqueado"
    echo -e "     • Sem conexão à internet${NC}"
    echo ""
    info "Verifique: npm config get proxy"
    info "Verifique: npm config get https-proxy"
  fi
fi

# Testa mirror alternativo (npmmirror para redes corporativas)
spinner_start "Testando latência do registry..."
REGISTRY_LATENCY=""
if command -v curl >/dev/null 2>&1; then
  REGISTRY_LATENCY=$(curl -o /dev/null -s -w "%{time_total}" --max-time 5 https://registry.npmjs.org/ 2>/dev/null || echo "")
fi
spinner_stop

if [ -n "$REGISTRY_LATENCY" ]; then
  LATENCY_MS=$(echo "$REGISTRY_LATENCY" | awk '{printf "%.0f", $1 * 1000}')
  if (( LATENCY_MS < 500 )); then
    ok "Latência do registry: ${BOLD}${LATENCY_MS}ms${NC} (ótima)"
  elif (( LATENCY_MS < 1500 )); then
    warn "Latência do registry: ${BOLD}${LATENCY_MS}ms${NC} (aceitável)"
  else
    warn "Latência do registry: ${BOLD}${LATENCY_MS}ms${NC} (alta — considere um mirror)"
    info "Mirror sugerido: npm config set registry https://registry.npmmirror.com"
  fi
fi

# ----------------------------------------------------------------
#  NPM CACHE
# ----------------------------------------------------------------
print_section "NPM CACHE"

CACHE_PATH=$(npm config get cache 2>/dev/null)

if [ -d "$CACHE_PATH" ]; then
  CACHE_SIZE=$(du -sh "$CACHE_PATH" 2>/dev/null | awk '{print $1}')
  SCORE_VERSION[CACHE]=$CACHE_SIZE
  ok "Cache encontrado: ${BOLD}${CACHE_PATH}${NC}"
  ok "Tamanho do cache: ${BOLD}${CACHE_SIZE}${NC}"
  SCORE[CACHE]=100
  SCORE_NOTE[CACHE]="ok (${CACHE_SIZE})"

  # Aviso se cache muito grande
  if [[ "$CACHE_SIZE" =~ ^[0-9]+(\.[0-9]+)?G$ ]]; then
    CACHE_GB=$(echo "$CACHE_SIZE" | sed 's/G//')
    if (( $(echo "$CACHE_GB >= 2" | bc -l 2>/dev/null || echo 0) )); then
      warn "Cache muito grande (${CACHE_SIZE}). Isso pode ocupar espaço desnecessário."
      fix_component "NPM Cache (limpeza)" "npm cache clean --force"
    fi
  fi

  # Verifica integridade
  if [ "$MINIMAL" = false ]; then
    spinner_start "Verificando integridade do cache..."
    if npm cache verify >/dev/null 2>&1; then
      spinner_stop
      ok "Cache íntegro."
    else
      spinner_stop
      warn "Cache pode estar corrompido."
      fix_component "NPM Cache (rebuild)" "npm cache verify"
    fi
  fi
else
  warn "Diretório de cache não encontrado: ${CACHE_PATH}"
  SCORE[CACHE]=50
  SCORE_NOTE[CACHE]="não encontrado"
  fix_component "Rebuild de cache" "npm cache verify"
fi

# ================================================================
#  SAÍDA EM JSON
# ================================================================

if [ "$JSON_OUTPUT" = true ]; then
  TOTAL=0; COUNT=0
  for k in NODE NPM NVM YARN PNPM BUN NETWORK CACHE; do
    TOTAL=$(( TOTAL + SCORE[$k] ))
    COUNT=$(( COUNT + 1 ))
  done
  AVG=$(( TOTAL / COUNT ))

  echo "{"
  echo "  \"version\": \"1.0.0\","
  echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"score\": $AVG,"
  echo "  \"components\": {"
  FIRST=true
  for k in NODE NPM NVM YARN PNPM BUN NETWORK CACHE; do
    [ "$FIRST" = false ] && echo ","
    FIRST=false
    VER="${SCORE_VERSION[$k]:-null}"
    NOTE="${SCORE_NOTE[$k]:-}"
    if [ "$VER" = "null" ]; then
      printf "    \"%s\": {\"score\": %d, \"note\": \"%s\"}" \
        "$(echo $k | tr '[:upper:]' '[:lower:]')" "${SCORE[$k]}" "$NOTE"
    else
      printf "    \"%s\": {\"score\": %d, \"version\": \"%s\", \"note\": \"%s\"}" \
        "$(echo $k | tr '[:upper:]' '[:lower:]')" "${SCORE[$k]}" "$VER" "$NOTE"
    fi
  done
  echo ""
  echo "  },"

  # Recomendações em JSON
  echo "  \"recommendations\": ["
  RECS=()
  (( SCORE[NODE]    < 100 )) && RECS+=("\"Atualizar Node para v22 LTS\"")
  (( SCORE[NPM]     < 100 )) && RECS+=("\"Atualizar NPM para v10+\"")
  (( SCORE[NVM]     < 100 )) && RECS+=("\"Instalar NVM ou alternativa (fnm/volta)\"")
  (( SCORE[YARN]    < 100 )) && RECS+=("\"Instalar Yarn para projetos legados\"")
  (( SCORE[PNPM]    < 100 )) && RECS+=("\"Instalar PNPM para melhor performance\"")
  (( SCORE[BUN]     < 100 )) && RECS+=("\"Instalar Bun (runtime + bundler moderno)\"")
  (( SCORE[NETWORK] < 100 )) && RECS+=("\"Verificar conectividade com registry.npmjs.org\"")
  (( SCORE[CACHE]   < 100 )) && RECS+=("\"Reconstruir ou limpar o cache NPM\"")

  for i in "${!RECS[@]}"; do
    if (( i < ${#RECS[@]} - 1 )); then
      echo "    ${RECS[$i]},"
    else
      echo "    ${RECS[$i]}"
    fi
  done
  echo "  ]"
  echo "}"
  exit 0
fi

# ================================================================
#  GRÁFICO DE SAÚDE DO ECOSSISTEMA
# ================================================================

print_section "GRÁFICO DE SAÚDE DO ECOSSISTEMA"

for k in NODE NPM NVM YARN PNPM BUN NETWORK CACHE; do
  draw_bar "$k" "${SCORE[$k]}"
done

# ================================================================
#  RESULTADO FINAL
# ================================================================

TOTAL=0; COUNT=0
for k in NODE NPM NVM YARN PNPM BUN NETWORK CACHE; do
  TOTAL=$(( TOTAL + SCORE[$k] ))
  COUNT=$(( COUNT + 1 ))
done
AVG=$(( TOTAL / COUNT ))

print_section "RESULTADO FINAL"

if   (( AVG >= 95 )); then
  STATUS="${GREEN}${BOLD}Ambiente impecável 🚀${NC}"
elif (( AVG >= 80 )); then
  STATUS="${YELLOW}${BOLD}Ambiente muito bom ⚙${NC}"
elif (( AVG >= 60 )); then
  STATUS="${YELLOW}Ambiente aceitável${NC}"
else
  STATUS="${RED}${BOLD}Ambiente precisa de manutenção pesada 🔥${NC}"
fi

echo -e "  Status: $STATUS"
echo -e "  Score Final: ${CYAN}${BOLD}${AVG}/100${NC}"
echo ""

# ================================================================
#  RECOMENDAÇÕES
# ================================================================

print_section "RECOMENDAÇÕES"

HAS_RECS=false

(( SCORE[NODE]    < 100 )) && { warn "Atualizar Node para v22 LTS:"; cmd "nvm install 22 && nvm use 22 && nvm alias default 22"; HAS_RECS=true; }
(( SCORE[NPM]     < 100 )) && { warn "Atualizar NPM:"; cmd "npm install -g npm@latest"; HAS_RECS=true; }
(( SCORE[NVM]     < 90  )) && { warn "Instalar NVM (ou alternativa fnm/volta):"; cmd "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash"; HAS_RECS=true; }
(( SCORE[YARN]    < 100 )) && { warn "Instalar Yarn (projetos legados):"; cmd "npm install -g yarn"; HAS_RECS=true; }
(( SCORE[PNPM]    < 100 )) && { warn "Instalar PNPM (performance + economia de disco):"; cmd "npm install -g pnpm"; HAS_RECS=true; }
(( SCORE[BUN]     < 100 )) && { warn "Instalar Bun (runtime + bundler moderno):"; cmd "curl -fsSL https://bun.sh/install | bash"; HAS_RECS=true; }
(( SCORE[NETWORK] < 100 )) && { warn "Verificar conectividade com o NPM registry."; HAS_RECS=true; }
(( SCORE[CACHE]   < 100 )) && { warn "Reconstruir ou limpar o cache NPM:"; cmd "npm cache clean --force"; HAS_RECS=true; }

[ "$HAS_RECS" = false ] && ok "Nenhuma recomendação — ambiente em excelente estado!"

# ================================================================
#  FOOTER
# ================================================================

echo ""
if [ "$LOG_ENABLED" = true ]; then
  echo -e "  ${GRAY}Log salvo em: ${CYAN}${LOG_FILE}${NC}"
fi
echo -e "  ${GREEN}✔${NC}  ${GRAY}Diagnóstico concluído.${NC}"
echo ""