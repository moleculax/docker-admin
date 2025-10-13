#!/bin/bash
# ===============================================
# 🚀 Administrador Profesional Docker
# Autor: Emilio J. Gomez
# ===============================================

# Colores
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

clear
echo -e "${BLUE}==============================================="
echo "  🐳 Administrador Profesional de Docker"
echo -e "===============================================${NC}"
echo -e "${YELLOW}⚠️ Este administrador solo funciona si Docker está instalado.${NC}"
echo -e "${YELLOW}Requiere permisos root o sudo para operar correctamente.${NC}"
echo ""

USER_LOGGED=$(whoami)
SUDO_CMD=""
DOCKER_STARTED=0

# ===============================================
# 🔐 Validación root o sudo
# ===============================================
validar_docker() {
    $SUDO_CMD docker info &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}⚠️ Docker daemon no está corriendo. Iniciando...${NC}"
        $SUDO_CMD systemctl start docker
        sleep 2
        $SUDO_CMD docker info &>/dev/null
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ No se pudo iniciar Docker daemon. Salga e inicie Docker manualmente.${NC}"
            exit 1
        else
            echo -e "${GREEN}✅ Docker daemon iniciado correctamente.${NC}"
            DOCKER_STARTED=1
        fi
    else
        DOCKER_STARTED=1
        echo -e "${GREEN}✅ Docker daemon está corriendo.${NC}"
    fi
}

# ===============================================
# 🔐 Selección modo ejecución
# ===============================================
if [ "$USER_LOGGED" != "root" ]; then
    while true; do
        echo -e "${BLUE}Seleccione el modo de ejecución:${NC}"
        echo "1) Ejecutar como root"
        echo "2) Ejecutar con sudo (usuario actual)"
        echo "3) Salir"
        read -rp "Opción [1-3]: " MODE

        case $MODE in
            1)
                echo -e "${YELLOW}🔑 Ingrese la clave de root para continuar...${NC}"
                exec su -c "bash $0" root
                ;;
            2)
                echo -e "${YELLOW}🔑 Validando permisos sudo...${NC}"
                sudo -k
                sudo true
                if [ $? -eq 0 ]; then
                    SUDO_CMD="sudo"
                    echo -e "${GREEN}✅ Permisos sudo verificados.${NC}"
                    break
                else
                    echo -e "${RED}❌ Clave sudo incorrecta. Intente nuevamente.${NC}"
                fi
                ;;
            3)
                echo "👋 Saliendo..."
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Opción inválida.${NC}"
                ;;
        esac
    done
fi

[ "$USER_LOGGED" == "root" ] && SUDO_CMD=""

# ===============================================
# 🔍 Verificar Docker instalado
# ===============================================
if ! command -v docker &>/dev/null; then
    echo -e "${RED}❌ Docker no está instalado. Instale Docker primero.${NC}"
    exit 1
fi

validar_docker
sleep 1

# ===============================================
# 🧭 Funciones
# ===============================================
listar_imagenes() {
    echo -e "${BLUE}📦 Imágenes disponibles:${NC}"
    $SUDO_CMD docker images
}

listar_contenedores() {
    echo -e "${BLUE}🐳 Contenedores en Docker:${NC}"
    $SUDO_CMD docker ps -a --format "table {{.Names}}\t{{.ID}}\t{{.Status}}\t{{.Image}}"
}

iniciar_contenedor() {
    IMAGES=($($SUDO_CMD docker images --format "{{.Repository}}:{{.Tag}}"))
    if [ ${#IMAGES[@]} -eq 0 ]; then
        echo -e "${RED}❌ No hay imágenes disponibles.${NC}"
        return
    fi

    echo -e "${BLUE}📦 Imágenes disponibles para iniciar contenedor:${NC}"
    for i in "${!IMAGES[@]}"; do
        echo "$((i+1))) ${IMAGES[$i]}"
    done

    read -rp "Seleccione el número de la imagen a iniciar: " NUM
    if ! [[ "$NUM" =~ ^[0-9]+$ ]] || [ "$NUM" -lt 1 ] || [ "$NUM" -gt "${#IMAGES[@]}" ]; then
        echo -e "${RED}❌ Selección inválida.${NC}"
        return
    fi

    IMG="${IMAGES[$((NUM-1))]}"
    CONTAINER_NAME="cont_${IMG//[:\/]/_}_$(date +%s)"

    CID=$($SUDO_CMD docker run -dit --name "$CONTAINER_NAME" "$IMG" bash 2>/dev/null || \
          $SUDO_CMD docker run -dit --name "$CONTAINER_NAME" "$IMG" sh)

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Contenedor iniciado: $IMG (Nombre: $CONTAINER_NAME, ID: $CID)${NC}"
    else
        echo -e "${RED}❌ No se pudo iniciar el contenedor. Verifique que la imagen tenga bash o sh.${NC}"
    fi
}

detener_contenedor() {
    CONTAINERS=($($SUDO_CMD docker ps --format "{{.Names}}:{{.ID}}"))
    if [ ${#CONTAINERS[@]} -eq 0 ]; then
        echo -e "${RED}❌ No hay contenedores activos.${NC}"
        return
    fi

    echo -e "${BLUE}🔧 Contenedores activos:${NC}"
    for i in "${!CONTAINERS[@]}"; do
        NAME=$(echo "${CONTAINERS[$i]}" | cut -d':' -f1)
        CID=$(echo "${CONTAINERS[$i]}" | cut -d':' -f2)
        echo "$((i+1))) $NAME ($CID)"
    done

    read -rp "Seleccione el número del contenedor a detener: " NUM
    if ! [[ "$NUM" =~ ^[0-9]+$ ]] || [ "$NUM" -lt 1 ] || [ "$NUM" -gt "${#CONTAINERS[@]}" ]; then
        echo -e "${RED}❌ Selección inválida.${NC}"
        return
    fi

    NAME=$(echo "${CONTAINERS[$((NUM-1))]}" | cut -d':' -f1)
    CID=$(echo "${CONTAINERS[$((NUM-1))]}" | cut -d':' -f2)
    $SUDO_CMD docker stop "$CID" && echo -e "${GREEN}🛑 Contenedor detenido: $NAME${NC}"
}

eliminar_imagen() {
    IMAGES=($($SUDO_CMD docker images --format "{{.Repository}}:{{.Tag}}"))
    if [ ${#IMAGES[@]} -eq 0 ]; then
        echo -e "${RED}❌ No hay imágenes para eliminar.${NC}"
        return
    fi

    echo -e "${BLUE}📦 Imágenes disponibles:${NC}"
    for i in "${!IMAGES[@]}"; do
        echo "$((i+1))) ${IMAGES[$i]}"
    done

    read -rp "Seleccione el número de la imagen a eliminar: " NUM
    if ! [[ "$NUM" =~ ^[0-9]+$ ]] || [ "$NUM" -lt 1 ] || [ "$NUM" -gt "${#IMAGES[@]}" ]; then
        echo -e "${RED}❌ Selección inválida.${NC}"
        return
    fi

    IMG="${IMAGES[$((NUM-1))]}"
    read -rp "¿Está seguro de eliminar la imagen '$IMG'? (s/n): " CONFIRM
    if [[ "$CONFIRM" =~ ^[sS]$ ]]; then
        $SUDO_CMD docker rmi "$IMG" && echo -e "${GREEN}🗑️ Imagen '$IMG' eliminada.${NC}"
    else
        echo -e "${RED}❌ Operación cancelada.${NC}"
    fi
}

mostrar_man() {
    clear
    echo -e "${BLUE}==============================${NC}"
    echo -e "${GREEN}📘 MANUAL BÁSICO DE DOCKER${NC}"
    echo -e "${BLUE}==============================${NC}"
    echo "docker ps             → Ver contenedores activos"
    echo "docker ps -a          → Ver todos los contenedores"
    echo "docker images         → Listar imágenes instaladas"
    echo "docker start <id>     → Iniciar un contenedor detenido"
    echo "docker stop <id>      → Detener un contenedor activo"
    echo "docker rmi <img>      → Eliminar una imagen"
    echo "docker logs <id>      → Ver logs de un contenedor"
    echo -e "${BLUE}==============================${NC}"
    read -rp "Presione ENTER para volver al menú..."
}

# ===============================================
# 🧭 Menú principal
# ===============================================
while true; do
    clear
    echo -e "${BLUE}==============================================="
    echo -e "🐳 Administrador Profesional Docker - by Emilio J. Gomez"
    echo -e "===============================================${NC}"
    echo -e "${GREEN}👤 Usuario actual: $USER_LOGGED${NC}"
    echo -e "${YELLOW}🔐 Modo: $( [ -z "$SUDO_CMD" ] && echo "root" || echo "sudo" )${NC}"
    echo ""
    echo "1) Listar imágenes"
    echo "2) Listar contenedores (activos y detenidos)"
    echo "3) Iniciar contenedor desde imagen"
    echo "4) Detener contenedor activo"
    echo "5) Eliminar imagen"
    echo "6) Ver MAN de comandos Docker"
    echo "7) Salir"
    echo ""
    read -rp "Seleccione una opción [1-7]: " OPC

    case $OPC in
        1) listar_imagenes ;;
        2) listar_contenedores ;;
        3) iniciar_contenedor ;;
        4) detener_contenedor ;;
        5) eliminar_imagen ;;
        6) mostrar_man ;;
        7) echo -e "${GREEN}👋 Saliendo del administrador...${NC}"; exit 0 ;;
        *) echo -e "${RED}❌ Opción inválida.${NC}" ;;
    esac

    echo ""
    read -rp "Presione ENTER para continuar..."
done
