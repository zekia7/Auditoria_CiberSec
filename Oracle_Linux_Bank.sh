#!/bin/bash

echo "========================================"
echo " AUDITORÍA DE SERVIDOR ORACLE LINUX"
echo "========================================"

# 1. Revisión de integridad de binarios críticos
echo -e "\n[1] Revisión de integridad de binarios críticos"
binarios=("/bin/ls" "/bin/bash" "/usr/bin/ssh" "/usr/bin/sudo")
for bin in "${binarios[@]}"; do
    if [ -f "$bin" ]; then
        echo "  - $bin:"
        sha256sum "$bin"
    else
        echo "  - $bin no encontrado."
    fi
done

# 2. Estado y configuración de SELinux o AppArmor
echo -e "\n[2] Estado y configuración de SELinux o AppArmor"
if command -v getenforce &>/dev/null; then
    echo "  SELinux: $(getenforce)"
    sestatus
elif command -v aa-status &>/dev/null; then
    echo "  AppArmor:"
    sudo aa-status
else
    echo "  Ningún sistema de control (SELinux/AppArmor) encontrado."
fi

# 3. Reglas de acceso a la red (mínimo privilegio)
echo -e "\n[3] Revisión de reglas de acceso a la red"
if command -v firewall-cmd &>/dev/null; then
    echo "  FirewallD:"
    sudo firewall-cmd --list-all
elif command -v iptables &>/dev/null; then
    echo "  Iptables:"
    sudo iptables -L -n -v
else
    echo "  No se detectó firewall configurado."
fi

# 4. Evaluación de rendimiento de memoria y swap
echo -e "\n[4] Rendimiento de memoria y swap"
free -h
swapon --show

# 5. Usuarios del sistema
echo -e "\n[5] Revisión de usuarios del sistema"
while IFS=: read -r username password uid gid gecos home shell; do
    if [ "$uid" -ge 1000 ] && [ "$username" != "nobody" ]; then
        echo "----------------------------------------"
        echo " Usuario: $username"
        echo " UID: $uid | GID: $gid | Home: $home | Shell: $shell"
        
        # Estado de la cuenta
        passwd_status=$(passwd -S "$username" 2>/dev/null | awk '{print $2}')
        case $passwd_status in
            L) status="❌ Bloqueado/Desactivado" ;;
            P) status="✅ Activo (con contraseña)" ;;
            NP) status="⚠️ Activo (sin contraseña)" ;;
            *) status="Estado desconocido" ;;
        esac
        echo " Estado de la cuenta: $status"

        # Detalles de contraseña y expiración
        echo " --- Detalles de contraseña (chage -l) ---"
        chage -l "$username"
    fi
done < /etc/passwd

# 6. Grupos y sus miembros
echo -e "\n[6] Revisión de grupos de usuarios"
getent group | awk -F: '{printf " Grupo: %-20s | GID: %-5s | Miembros: %s\n", $1, $3, $4}'

echo -e "\n========================================"
echo " FIN DE AUDITORÍA"
echo "========================================"
