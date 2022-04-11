#!/bin/bash

#Author: Diego Rubi Salas.
#Date:  2022-04-06

#Colores
COLOR_RESET="\033[0m\e[0m"
COLOR_RED="\e[0;31m\033[1m"
COLOR_GREEN="\e[0;32m\033[1m"
COLOR_YELLOW="\e[0;33m\033[1m"
COLOR_BLUE="\e[0;34m\033[1m"
COLOR_GRAY="\e[0;37m\033[1m"
COLOR_PURPLE="\e[0;35m\033[1m"

#Variables Globales
unconfirmed_transactions_url="https://www.blockchain.com/es/btc/unconfirmed-transactions/"
inspect_transaction_url="https://www.blockchain.com/es/btc/tx/"
inspect_address_url="https://www.blockchain.com/es/btc/address/"
get_bitcoin_value="https://cointelegraph.com/bitcoin-price"

#Funciones de Ayuda
function remove_temp_files(){
    rm -f ./*.table ./*.tmp 2>/dev/null 2>&1;
}

function exitApplication(){
    remove_temp_files;
    tput cnorm;

    if [ "$1" -ne "0" ]; then
        echo -e "${COLOR_RED}[!] Error! Cerrando aplicacion..."
    fi

    exit $1
}

#Funcion encargada de mostrar mensaje de salida, cuando el usuario aplique el comando Ctrl+C.
function ctrl_c(){
    echo -e "\n${COLOR_RED}[!] Saliendo...\n${COLOR_RESET}";
    exitApplication 1;
}

function helpMenu(){
    echo -e "\n${COLOR_RED}[!] Uso: ./BitcoinAnalyzer.sh${COLOR_RESET}"
    
    for i in $(seq 1 80); do 
        echo -ne "${COLOR_RED}-"; 
    done; 
    
    echo -ne "${COLOR_RESET}";
    echo -e "\n\n\t${COLOR_GRAY}[-e] ${COLOR_RESET}${COLOR_YELLOW}Modo Exploracion:${COLOR_RESET}";
    echo -e "\t\t${COLOR_PURPLE}unconfirmed_transactions${COLOR_RESET}${COLOR_YELLOW}:\tListar Transacciones no confirmadas.${COLOR_RESET}"
    echo -e "\t\t${COLOR_GRAY}[-n] ${COLOR_RESET}${COLOR_YELLOW}Limitar el numero de resultados. ${COLOR_RESET}${COLOR_BLUE}(Ejemplo: -n 10) ${COLOR_RED}No exceder los 50 registros.\n${COLOR_RESET}"
    echo -e "\t\t${COLOR_PURPLE}inspect_transaction${COLOR_RESET}${COLOR_YELLOW}:\t\tInspeccionar un hash de transacción.${COLOR_RESET}"
    echo -e "\t\t${COLOR_GRAY}[-i] ${COLOR_RESET}${COLOR_YELLOW}Proporcionar identificador de transacción ${COLOR_RESET}${COLOR_BLUE}(Ejemplo: -i 87e48fd4ee79b12946021d7482d1099ccf5f67bec947946dcdbf33138a05019e)\n${COLOR_RESET}"
    echo -e "\t\t${COLOR_PURPLE}address_transaction${COLOR_RESET}${COLOR_YELLOW}:\t\tInspeccionar una transacción de dirección.${COLOR_RESET}"
    echo -e "\t\t${COLOR_GRAY}[-a] ${COLOR_RESET}${COLOR_YELLOW}Proporcionar una dirección de transacción ${COLOR_RESET}${COLOR_BLUE}(Ejemplo: -a 19iqYbeATe4RxghQZJnYVFU4mjUUu76EA6)\n${COLOR_RESET}"
    echo -e "\t\t${COLOR_PURPLE}currency_converter${COLOR_RESET}${COLOR_YELLOW}:\t\tCalcula la cantidad de Bitcoins en Dolares y viceversa.${COLOR_RESET}"
    echo -e "\t\t${COLOR_GRAY}[-b] ${COLOR_RESET}${COLOR_YELLOW}Proporcionar la cantidad bitcoins que desea convertir ${COLOR_RESET}${COLOR_BLUE}(Ejemplo: -b 0.00004514)${COLOR_RESET}"
    echo -e "\t\t${COLOR_GRAY}[-d] ${COLOR_RESET}${COLOR_YELLOW}Proporcionar la cantidad dolares que desea convertir ${COLOR_RESET}${COLOR_BLUE}(Ejemplo: -d 45.6)\n${COLOR_RESET}"
    echo -e "\n\t${COLOR_GRAY}[-h] ${COLOR_RESET}${COLOR_YELLOW}Mostrar este panel de ayuda.${COLOR_RESET}"

    exitApplication 0;
}

#Funciones para crear la tabla de resultados
function printTable(){
    local -r delimiter="${1}"
    local -r data="$(removeEmptyLines "${2}")"

    if [[ "${delimiter}" != '' && "$(isEmptyString "${data}")" = 'false' ]]
    then
        local -r numberOfLines="$(wc -l <<< "${data}")"

        if [[ "${numberOfLines}" -gt '0' ]]
        then
            local table=''
            local i=1

            for ((i = 1; i <= "${numberOfLines}"; i = i + 1))
            do
                local line=''
                line="$(sed "${i}q;d" <<< "${data}")"

                local numberOfColumns='0'
                numberOfColumns="$(awk -F "${delimiter}" '{print NF}' <<< "${line}")"

                if [[ "${i}" -eq '1' ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi

                table="${table}\n"

                local j=1

                for ((j = 1; j <= "${numberOfColumns}"; j = j + 1))
                do
                    table="${table}$(printf '#| %s' "$(cut -d "${delimiter}" -f "${j}" <<< "${line}")")"
                done

                table="${table}#|\n"

                if [[ "${i}" -eq '1' ]] || [[ "${numberOfLines}" -gt '1' && "${i}" -eq "${numberOfLines}" ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi
            done

            if [[ "$(isEmptyString "${table}")" = 'false' ]]
            then
                echo -e "${table}" | column -s '#' -t | awk '/^\+/{gsub(" ", "-", $0)}1'
            fi
        fi
    fi
}

function removeEmptyLines(){
    local -r content="${1}"
    echo -e "${content}" | sed '/^\s*$/d'
}

function repeatString(){
    local -r string="${1}"
    local -r numberToRepeat="${2}"

    if [[ "${string}" != '' && "${numberToRepeat}" =~ ^[1-9][0-9]*$ ]]
    then
        local -r result="$(printf "%${numberToRepeat}s")"
        echo -e "${result// /${string}}"
    fi
}

function isEmptyString(){
    local -r string="${1}"

    if [[ "$(trimString "${string}")" = '' ]]
    then
        echo 'true' && return 0
    fi

    echo 'false' && return 1
}

function trimString(){
    local -r string="${1}"
    sed 's,^[[:blank:]]*,,' <<< "${string}" | sed 's,[[:blank:]]*$,,'
}

function getUnconfirmedTransactions(){
    
    # FIXME: error en caso de estar en el idioma EN.

    number_output=$1;

    echo -e "Mostrando los ultimos ${number_output} datos...\n"

    echo '' > ut.tmp;

    while [ "$(cat ut.tmp | wc -l)" == "1" ]; do
        curl -s "${unconfirmed_transactions_url}" | html2text > ut.tmp;
    done
    
    hashes=$(cat ut.tmp | grep -A 1 "Hash" | grep -v -E "Hash|Tiempo|Time|\--" | head -n ${number_output})

    echo "${COLOR_BLUE}Hash${COLOR_RESET}_${COLOR_GREEN}Monto${COLOR_RESET}_${COLOR_YELLOW}Bitcoin${COLOR_RESET}_${COLOR_BLUE}Tiempo${COLOR_RESET}" > ut.table
    
    for hash in $hashes; do
        echo "${COLOR_BLUE}${hash}${COLOR_RESET}_${COLOR_GREEN}\$ $(cat ut.tmp | grep "$hash" -A 6 | tail -n 1 | awk '{ print substr( $0, 1, length($0)-5 ) }' | sed 's/\$//g')${COLOR_RESET}_${COLOR_YELLOW}$(cat ut.tmp | grep "$hash" -A 4 | tail -n 1)${COLOR_RESET}_${COLOR_BLUE}$(cat ut.tmp | grep "$hash" -A 2 | tail -n 1)${COLOR_RESET}" >> ut.table;
    done 

    money=0 #Variable para almacenar la cantidad de dinero en las ultimas transacciones.

    #Toma los datos de la tabla, pero elimina los decimales de los valores.
    cat ut.table | tr '_' ' ' | awk '{print $3}' | grep -v 'Bitcoin' | sed 's/\\033\[0m\\e\[0m//g' | sed 's/\.*//g' | sed 's/\,.*//g' > moneyFile.tmp;

    cat moneyFile.tmp | while read money_line; do
        let money+=$money_line;
        echo $money > money.tmp;
    done; 

    echo -ne "${COLOR_BLUE}Cantidad Total_${COLOR_RESET}" > amount.table;
    echo "${COLOR_GREEN}\$ $(printf "%'.d\n" $(cat money.tmp))${COLOR_RESET}" >> amount.table;

    if [ "$(cat ut.table | wc -l)" != "1" ]; then
        printTable '_' "$(cat ut.table)";
        echo ''
        printTable '_' "$(cat amount.table)";
    fi

    exitApplication 0;
}

function getTransaction(){
    inspect_transaction_hash=$1;

    curl -s ${inspect_transaction_url}${inspect_transaction_hash} > inspect_transaction.tmp

    echo -e "${COLOR_BLUE}Entradas totales_Gastos totales${COLOR_RESET}" > transaction.tmp;
    while [ "$(cat transaction.tmp | wc -l)" == "1" ]; do
        cat inspect_transaction.tmp | html2text | grep -E "Entradas totales|Gastos totales|Total Input|Total Output" -A 1 | grep -v -E "Entradas totales|Gastos totales|Total Input|Total Output" | xargs | tr ' ' '_' | sed 's/_BTC/ BTC/g' >> transaction.tmp
    done

    printTable "_" "$(cat transaction.tmp)"

    echo -e "${COLOR_BLUE}Direccion (Entradas)_Valor${COLOR_RESET}" > entradas.tmp;
    while [ "$(cat entradas.tmp | wc -l)" == "1" ]; do
        cat inspect_transaction.tmp | html2text | grep -E "Entradas$|Inputs$" -A 500 | grep -E "Gastos$|Outputs$" -B 500 | grep -E "Direcc|Valor$|Address$|Value$" -A 1 | grep -v -E "Direcci|Valor|Address|Value|\--" | awk 'NR%2{printf "%s_", $0;next;} 1' >> entradas.tmp
    done

    printTable '_' "$(cat entradas.tmp)";

    echo -e "${COLOR_BLUE}Direccion (Salidas)_Valor${COLOR_RESET}" > salidas.tmp;
    while [ "$(cat salidas.tmp | wc -l)" == "1" ]; do
        cat inspect_transaction.tmp | html2text | grep -E "Gastos$|Outputs$" -A 500 | grep -E "Ya lo has pensado|You" -B 500 | grep -E "Direcc|Valor$|Address$|Value$" -A 1 | grep -v -E "Direcci|Valor|Address|Value|\--" | awk 'NR%2{printf "%s_", $0;next;}1' >> salidas.tmp
    done

    printTable '_' "$(cat salidas.tmp)";


    exitApplication 0;
}

function getBitcoinValue(){
    echo -e "${COLOR_YELLOW}Obteniendo valor actual del bitcoin...${COLOR_RESET}";

    #Obtiene el valor del bitcoin actualmente desde la pagina cointelegraph.
    bitcoin_value=$(curl -s "https://cointelegraph.com/bitcoin-price" | html2text | grep "Last Price" | head -n 1 | awk 'NF{print $NF}' | tr ',' '.' | sed 's/\$//g');
    echo -e "${COLOR_PURPLE}[!] Valor del Bitcoin actual es de: \$${bitcoin_value}${COLOR_RESET}"
}

function getAddress(){
    address_hash=$1;

    echo "Transacciones realizadas_Cantidad Total Recibida (BTC)_Cantidad Total Enviada (BTC)_Saldo total en la cuenta (BTC)" > address.tmp;

    curl -s "${inspect_address_url}${address_hash}" | html2text | grep -E "Transacciones|Total recibido|Total enviado|Saldo final|^Transactions|Total Received|Total Sent|Final Balance" -A 1 | head -n -2 | grep -E -v "Transacciones|Total recibido|Total enviado|Saldo final|^Transactions|Total Received|Total Sent|Final Balance" | xargs | tr ' ' '_' |  sed 's/_BTC/ BTC/g' >> address.tmp;
    
    echo -e ${COLOR_YELLOW};
    printTable '_' "$(cat address.tmp)";
    echo -e ${COLOR_RESET};
    
    #Obtiene el valor del bitcoin actualmente desde la pagina cointelegraph.
    #bitcoin_value=$(curl -s "https://cointelegraph.com/bitcoin-price" | html2text | grep "Last Price" | head -n 1 | awk 'NF{print $NF}' | tr ',' '.' | sed 's/\$//g');
    getBitcoinValue

    echo "Transacciones realizadas_Cantidad Total Recibida (Dolares)_Cantidad Total Enviada (Dolares)_Saldo total en la cuenta (Dolares)" > address_dlr.table;
    
    curl -s "${inspect_address_url}${address_hash}" | html2text | grep -E "Transacciones|^Transactions" -A 1 | head -n -2 | grep -E -v "Transacciones|^Transactions|\--" > address_dlr.tmp;
    curl -s "${inspect_address_url}${address_hash}" | html2text | grep -E "Total recibido|Total enviado|Saldo final|Total Received|Total Sent|Final Balance" -A 1  | grep -E -v "Total recibido|Total enviado|Saldo final|Total Received|Total Sent|Final Balance" | sed 's/ BTC//g' | tr ',' '.' >> btc_to_dlr.tmp;

    cat btc_to_dlr.tmp | while read value; do 
        echo -e "\$ $(printf "%'.8f\n" $(echo "$value $bitcoin_value"  | awk '{print $1*$2}'))" >> address_dlr.tmp;
    done;

    cat address_dlr.tmp | xargs | sed 's/ \$/_\$/g' >> address_dlr.table;

    echo -e ${COLOR_GREEN};
    printTable '_' "$(cat address_dlr.table)";
    echo -e ${COLOR_RESET}; 

    exitApplication 0;
}

function convertCurrency(){
    # Esta funcion recibe dos argumentos.
    # El primero indica la moneda de procedencia y el segundo la cantidad a convertir. 

    currency=$1
    value="$(echo $2 | sed 's/\,//g')";

    getBitcoinValue;

    if [ "$currency" -eq '1' ]; then
        echo -e "Bitcoin: ${value} -> Dolares \$ $(printf "%'.8f\n" $(echo "$value $bitcoin_value"  | awk '{print $1*$2}'))"
    fi

    if [ "$currency" -eq '2' ]; then
        echo -e "Dolares \$ $(printf "%'.2f" $value) -> Bitcoin: $(printf "%'.8f\n" $(echo "$value $bitcoin_value" | awk '{print $1/$2}')) BTC"; 
    fi

    exitApplication 0;
}

#######################################################################################################################
#   Obtiene argumentos ingresados por el usuario.
#######################################################################################################################

trap ctrl_c INT
#Establece el cursor invisible.
tput civis;

#Contador de los argumentos del programa.
parameter_counter=0;

bitcoin_value=0;

while getopts "e:n:i:a:b:d:h:" arg; do
    case $arg in
        e) 
            exploration_mode=$OPTARG;
            let parameter_counter+=1;
        ;;
        n)
            number_output=$OPTARG;
            let parameter_counter+=1;
        ;;
        i)
            inspect_transaction_hash=$OPTARG;
            let parameter_counter+=1;
        ;;
        a)
            inspect_address_hash=$OPTARG;
            let parameter_counter+=1;
        ;;
        b)
            bitcoin_convert=$OPTARG;
            let parameter_counter+=1;
        ;;
        d)
            dolar_convert=$OPTARG;
            let parameter_counter+=1;
        ;;
        h)
            helpMenu;
        ;;
    esac
done



#En caso de que el contador de los parametros sea 0 muestre el menu de ayuda.
if [ $parameter_counter -eq 0 ]; then
    helpMenu;
else
    if [ "$(echo $exploration_mode)" == "unconfirmed_transactions" ]; then
        if [ ! "$number_output" ]; then
            number_output=50;
            getUnconfirmedTransactions $number_output;
        else
            if [ "$number_output" -lt "1" ]; then
                echo -e "${COLOR_RED}[!] Imposible mostrar menos de 1 registro.${COLOR_RESET}"
                exitApplication 2;
            fi

            if [ "$number_output" -gt "50" ]; then
                echo -e "${COLOR_YELLOW}La cantidad maxima de datos que pueden ser solicitados son 50.${COLOR_RESET}";
                number_output=50;
                getUnconfirmedTransactions $number_output;
            else
                getUnconfirmedTransactions $number_output;
            fi            
        fi
    elif [ "$(echo $exploration_mode)" == "inspect_transaction" ]; then
        if [ ! "$inspect_transaction_hash" ]; then
            helpMenu;
        else
            getTransaction $inspect_transaction_hash;
        fi
    elif [ "$(echo $exploration_mode)" == "address_transaction" ]; then
        if [ ! "$inspect_address_hash" ]; then
            helpMenu;
        else
            getAddress $inspect_address_hash;
        fi
    elif [ "$(echo $exploration_mode)" == "currency_converter" ]; then
        if [ ! "$bitcoin_convert" ] && [ ! "$dolar_convert" ]; then
            helpMenu
        else
            if [ "$bitcoin_convert" ] && [ ! "$dolar_convert" ]; then
                convertCurrency "1" "$bitcoin_convert";
            fi

            if [ ! "$bitcoin_convert" ] && [ "$dolar_convert" ]; then
                convertCurrency "2" "$dolar_convert";
            fi   
        fi
    else
        helpMenu;
    fi
fi

#Si la aplicacion no encuentra una ruta de ejecucion.
exitApplication 3;
