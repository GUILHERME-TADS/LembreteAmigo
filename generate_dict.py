def num_to_word(n, is_hour=False):
    words = {
        0: 'zero', 1: 'uma' if is_hour else 'um', 2: 'duas' if is_hour else 'dois', 3: 'tres', 4: 'quatro', 
        5: 'cinco', 6: 'seis', 7: 'sete', 8: 'oito', 9: 'nove', 10: 'dez', 
        11: 'onze', 12: 'doze', 13: 'treze', 14: 'quatorze', 15: 'quinze',
        16: 'dezesseis', 17: 'dezessete', 18: 'dezoito', 19: 'dezenove',
        20: 'vinte', 30: 'trinta', 40: 'quarenta', 50: 'cinquenta'
    }
    if n in words:
        return words[n]
    tens = (n // 10) * 10
    units = n % 10
    return f'{words[tens]} e {words[units]}'

with open('lib/utils/time_dictionary.dart', 'w', encoding='utf-8') as f:
    f.write('// Gerado por IA para mapear todas as combinacoes de 00:00 a 23:59\n')
    f.write('class TimeDictionary {\n')
    f.write('  static const Map<String, String> map = {\n')
    
    entries = {}
    
    for h in range(24):
        for m in range(60):
            time_str = f'{h:02d}:{m:02d}'
            
            # Hora por extenso
            h_word = num_to_word(h, is_hour=True)
            
            # Minutos por extenso
            m_word = num_to_word(m)
            
            phrases = []
            
            # Minuto 00
            if m == 0:
                phrases.append(f'{h_word} horas')
                phrases.append(f'{h_word} em ponto')
            elif m == 30:
                phrases.append(f'{h_word} e meia')
                phrases.append(f'{h_word} e trinta')
                phrases.append(f'{h_word} horas e meia')
            else:
                phrases.append(f'{h_word} e {m_word}')
                phrases.append(f'{h_word} horas e {m_word}')
            
            # Tratar periodos do dia (1 a 11)
            if 1 <= h <= 11 or h == 0 or h == 12:
                # 0 = meia noite, 12 = meio dia
                if h == 0:
                    base = 'meia noite'
                elif h == 12:
                    base = 'meio dia'
                else:
                    base = num_to_word(h, is_hour=True)
                
                # Para h de 1 a 11, podemos ter tarde/noite que viram 13 a 23
                if 1 <= h <= 11:
                    if m == 0:
                        entries[f'{base} da manha'] = f'{h:02d}:00'
                        entries[f'{base} da tarde'] = f'{h+12:02d}:00'
                        if h >= 6:
                            entries[f'{base} da noite'] = f'{h+12:02d}:00'
                        else:
                            entries[f'{base} da madrugada'] = f'{h:02d}:00'
                    elif m == 30:
                        entries[f'{base} da manha e meia'] = f'{h:02d}:30'
                        entries[f'{base} da tarde e meia'] = f'{h+12:02d}:30'
                        if h >= 6:
                            entries[f'{base} da noite e meia'] = f'{h+12:02d}:30'
                    else:
                        entries[f'{base} da manha e {m_word}'] = f'{h:02d}:{m:02d}'
                        entries[f'{base} da tarde e {m_word}'] = f'{h+12:02d}:{m:02d}'
                        if h >= 6:
                            entries[f'{base} da noite e {m_word}'] = f'{h+12:02d}:{m:02d}'

                # Para meia noite e meio dia
                if h == 0:
                    if m == 0:
                        entries['meia noite'] = '00:00'
                    elif m == 30:
                        entries['meia noite e meia'] = '00:30'
                    else:
                        entries[f'meia noite e {m_word}'] = f'00:{m:02d}'
                if h == 12:
                    if m == 0:
                        entries['meio dia'] = '12:00'
                    elif m == 30:
                        entries['meio dia e meia'] = '12:30'
                    else:
                        entries[f'meio dia e {m_word}'] = f'12:{m:02d}'

            for p in phrases:
                entries[p] = time_str

    # Ordenar por tamanho da chave decrescente para que strings maiores deem match primeiro
    sorted_entries = dict(sorted(entries.items(), key=lambda item: len(item[0]), reverse=True))

    for key, val in sorted_entries.items():
        f.write(f'    \"{key}\": \"{val}\",\n')
        
    f.write('  };\n')
    f.write('}\n')

print(f"Gerado e ordenado com {len(sorted_entries)} combinacoes")
