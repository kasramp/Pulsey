#!/bin/bash

backtitle="Pulsey v0.1"
dialog --backtitle "$backtitle" --title "Welcome" --msgbox "This utility allows you to switch sound card easily.\n\nIt is a wrapper on top of 'pacmd' for easy configuration." "12" "40"

IFS=$'\n'
sound_cards=($(pacmd list-cards |  grep -Po '(?<=index:\s|name:\s)[^\s]*' | tr -d "<" | tr -d ">"))
active_cards=($(pacmd list-sinks | grep 'index:' | sed -e 's/^\s*//' -e '/^$/d'))

sound_selector=""
has_set=0

for ((i = 0; i < ${#sound_cards[@]}; i++))
do
    sound_selector="$sound_selector ${sound_cards[$i]}"
    if [ $(( $i % 2 )) -ne 0 ]
    then
        if [ $has_set -eq 0 ]
        then
            previous_index=$(expr $i - 1)
            previous_entry="* index: ${sound_cards[$previous_index]}"
            for ((j=0; j< ${#active_cards[@]}; j++))
            do
                if [ "$previous_entry" == "${active_cards[$j]}" ]
                then
                    has_set=1
                fi
            done
            if [ $has_set -eq 1 ]
            then
                sound_selector="$sound_selector ON"
            else
                sound_selector="$sound_selector OFF"
            fi
        else
            sound_selector="$sound_selector OFF"
        fi
    fi
done

unset IFS

card_response=$(dialog --backtitle "$backtitle" --title "Cards" --scrollbar --nocancel --radiolist --output-fd 1 "Select a sound card:" 15 70 50 $sound_selector)
result=$?

if [ $result -eq 255 ]
then
    reset
    exit 0
fi
 
selected_card=$(pacmd list-cards | awk "/index: $card_response/,/ports:/")

active_profile=$(echo "$selected_card" | grep -Po '(?<=profiles:\s|active profile:\s)[^\s]*' | tr -d "<" | tr -d ">")

IFS=$'\n'
profiles=($(echo "$selected_card" | awk '/profiles:/,/active profile:/' | head -n -1 | tail -n +2))
unset IFS

profile_selector=""

for ((i = 0; i < ${#profiles[@]}; i++))
do
    trim=$(echo ${profiles[$i]} | xargs)
    tag=$(echo "$trim" | awk -F ": " '{print $1}')
    item=${trim#*: }
    if [ "$tag" == "$active_profile" ]
    then
        profile_selector="$profile_selector \"$tag\" \"$item\" \"ON\""
    else
        profile_selector="$profile_selector \"$tag\" \"$item\" \"OFF\""
    fi
done

cmd="dialog --backtitle \"$backtitle\" --title \"Profile\" --scrollbar --nocancel --radiolist --output-fd 1 'Select a profile:' 15 120 10 $profile_selector"

response=$(eval $cmd)
result=$?

if [ $result -ne 255 ]
then
    if [ -n "$card_response" ] && [ -n "$response" ]
    then
        pacmd set-default-source $card_response
        pacmd set-card-profile $card_response $response
        pacmd set-default-sink $card_response
        pulseaudio -k
    fi
fi

reset

