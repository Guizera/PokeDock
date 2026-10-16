# pokeTab

Protótipo macOS de encontros Pokémon pelo ícone do app no Dock.

## Idiomas

O app está localizado em português do Brasil e inglês. Ele acompanha o idioma preferido do macOS. Para usar inglês apenas no PokeDock, abra **Ajustes do Sistema → Geral → Idioma e Região → Aplicativos**, adicione o app e selecione **English**. Se o app já estiver aberto, encerre-o e abra-o novamente. Os nomes de Pokémon e os dados salvos continuam os mesmos em ambos os idiomas.

## Fluxo atual

- O app sorteia um encontro enquanto está aberto. O primeiro aparece após cerca de 2 a 4 minutos; depois, a frequência Normal espera de 20 a 35 minutos entre encontros. Um Pokémon aparece no ícone de grama do app, que também recebe um sinal de exclamação por cinco minutos. Pidgey, Rattata e outros Pokémon comuns têm mais chances de aparecer.
- Quando há um encontro, o Pokémon aparece no lugar da mascote do tema na barra personalizada. Clicar nesse Pokémon abre a janela inspirada no Game Boy; abrir a Pokédex ou ativar o PokeDock não abre mais o encontro automaticamente.
- O estoque começa com 10 Pokébolas e volta a 10 duas horas depois da primeira utilizada. Cada lançamento consome uma bola. A captura fica mais difícil conforme a raridade. A primeira falha nunca faz o Pokémon fugir; da segunda falha em diante, há uma chance de fuga baseada na raridade e no número de tentativas. O estoque, a recarga e as tentativas do encontro são salvos localmente.
- A Pokédex lista as 151 espécies da primeira geração e separa capturados, vistos, desconhecidos e capturas repetidas.
- Preferências oferecem três frequências e uma pausa manual: Tranquila (45 a 70 minutos), Normal (20 a 35 minutos) e Animada (10 a 20 minutos). Os intervalos são contados em tempo corrido; um encontro pendente pode surgir logo após reabrir o app.
- A barra Pokémon personalizada oferece seis temas: Pradaria, Elétrico, Noturno, Oceano, Vulcânico e Psíquico. Cada tema tem efeitos próprios, como folhas, raios, névoa, ondas, brasas e orbes.
- A barra cresce ou diminui conforme os itens e apps em execução, fica centralizada e para de crescer ao alcançar a largura disponível na tela; os itens excedentes podem ser rolados horizontalmente.
- O editor do Dock permite ordenar apps e widgets, ligar ou desligar as animações e mostrar apps em execução. Além de relógio, Pokédex e próximo encontro, há widgets de Spotify, Música, dólar USD/BRL, orçamento mensal, foco, tarefas, notas rápidas e Arcade retrô.
- Os ícones de apps na barra abrem apps fechados e trazem apps em execução para frente. Apps fixados exibem um ponto quando estão abertos.
- Clique com o botão direito em um ícone para encerrar o app em execução ou removê-lo da barra. Remover um app fixado salva a alteração; remover um ícone temporário de app em execução o oculta até o app fechar. O Finder oferece apenas a opção de remoção, pois o macOS o gerencia.
- Finder e Lixeira são adicionados por padrão. O clique na Lixeira abre a visualização do Finder e pode pedir permissão de Automação na primeira vez; se ela for negada, o app tenta abrir a pasta local da Lixeira.
- Os players mostram capa, faixa e artista e permitem voltar, pausar ou avançar quando o app de música está aberto e o usuário concede acesso à Automação. A cotação é uma referência diária da [Frankfurter](https://frankfurter.dev/), com data visível, e fica em cache para uso sem rede. Orçamento, tarefas e notas são salvos localmente.
- O Arcade retrô abre uma TV do tamanho da janela de encontro. Ele inclui Cobrinha e Memória, além de emuladores para Game Boy Color e Super Nintendo. As ROMs não são distribuídas com o app: cada usuário importa sua própria cópia e o PokeDock valida a compatibilidade antes de guardá-la localmente.
- Na primeira abertura, a barra personalizada já fica ativa e o app solicita a permissão de Automação usada para ocultar automaticamente a Dock nativa. Quem desativa a barra mantém essa preferência. Há também uma opção para abrir o PokeDock ao iniciar a sessão do macOS.
- Estado e preferências são salvos localmente com UserDefaults. Não há conta; o app consulta o feed de atualizações do GitHub Releases pelo Sparkle.

## Atualizações

O app usa Sparkle 2. O menu **Poke Dock → Verificar atualizações…** permite procurar uma versão nova; o Sparkle também faz verificações periódicas. O feed fica em `https://github.com/Guizera/PokeDock/releases/latest/download/appcast.xml`. Cada release estável do repositório do app deve incluir dois arquivos anexados: `PokeDock.dmg` e `appcast.xml`.

Para publicar uma versão:

1. Aumente `MARKETING_VERSION` e `CURRENT_PROJECT_VERSION` no projeto Xcode. O número do build deve sempre crescer.
2. Faça um Archive e distribua com **Developer ID** pelo Xcode. Depois que a notarização for aceita, exporte novamente o `.app` para incluir o ticket. Confira com `codesign --verify --deep --strict /caminho/pokeTab.app` e `xcrun stapler validate /caminho/pokeTab.app`.
3. Crie o DMG com `scripts/package_dmg.sh /caminho/pokeTab.app dist/releases/vVERSAO/PokeDock.dmg`. Ele inclui o app e um atalho para `/Applications`. O script não substitui um DMG existente.
4. Assine o DMG com uma identidade **Developer ID Application** instalada no Chaves, envie o próprio DMG ao serviço de notarização e grampeie o ticket. Exemplo para a versão 1.1.0:

   ```sh
   security find-identity -p codesigning -v
   codesign --sign "Developer ID Application: Jose Alves da Cunha (T55Q6Y63L5)" --timestamp --identifier com.guilhermecunha.pokeTab.dmg dist/releases/v1.1.0/PokeDock.dmg
   xcrun notarytool store-credentials PokeDock --apple-id "seu@email.com" --team-id T55Q6Y63L5
   xcrun notarytool submit dist/releases/v1.1.0/PokeDock.dmg --keychain-profile PokeDock --wait
   xcrun stapler staple dist/releases/v1.1.0/PokeDock.dmg
   xcrun stapler validate dist/releases/v1.1.0/PokeDock.dmg
   spctl --assess --type open --context context:primary-signature --verbose=4 dist/releases/v1.1.0/PokeDock.dmg
   ```

   O `store-credentials` pede uma **senha específica de app** no terminal; não digite a senha normal da Conta Apple nem coloque a senha na linha de comando. Se `security find-identity` não mostrar a identidade Developer ID Application, crie ou importe no Chaves um certificado com sua chave privada antes de assinar. O certificado usado pelo Xcode na exportação pode ser gerenciado na nuvem e não estar disponível para o `codesign` local.
5. Localize o `generate_appcast` do pacote Sparkle em `SourcePackages/artifacts/sparkle/Sparkle/bin/` e execute `scripts/prepare_release.sh VERSAO CAMINHO_DO_DMG CAMINHO_DO_GENERATE_APPCAST`. Exemplo: `scripts/prepare_release.sh 1.1.0 dist/releases/v1.1.0/PokeDock.dmg /caminho/para/generate_appcast`. O script só gera o feed depois de verificar a assinatura e o ticket do DMG; rode-o **depois** de grampear o ticket, pois isso altera o arquivo usado na assinatura Ed25519 do Sparkle.
6. Crie uma release **rascunho** com a tag `vVERSAO` no repositório `Guizera/PokeDock`, anexe `PokeDock.dmg` e `appcast.xml` de `dist/releases/vVERSAO/` e só então publique. Teste a atualização a partir da versão anterior instalada em `/Applications`.

A chave privada Ed25519 do Sparkle fica no Chaves do macOS, na conta `com.guilhermecunha.pokeTab`. Faça um backup seguro dela; o projeto guarda somente a chave pública. O DMG 1.0 atual não contém Sparkle: quem o instalou precisará instalar manualmente a versão 1.1.0 uma vez. As versões posteriores poderão atualizar pelo app.

## Testar

Abra pokeTab.xcodeproj no Xcode e execute o esquema pokeTab em My Mac. Em Preferências, use **Simular um encontro agora** para testar sem esperar pelo temporizador. Esse botão aparece apenas no build Debug.

Abra **Personalizar Dock** pela barra, pela barra de ferramentas da Pokédex ou por **Preferências → Dock Pokémon**. No editor, escolha um tema, adicione apps e widgets e use as setas para ordená-los. Na primeira abertura, a barra já vem ativa. O pokeTab liga **Ocultar e mostrar Dock automaticamente** no macOS e pode pedir permissão para controlar **Eventos do Sistema**. Se a ocultação automática estava desligada, o pokeTab a restaura quando a barra é desativada. A Dock original ainda reaparece quando o cursor chega à borda da tela. A opção **Abrir ao iniciar sessão** fica nas configurações da Dock e depende da autorização do macOS.

Para usar um player, abra Spotify ou Música, adicione o widget e clique em **Conectar** na barra. O macOS poderá solicitar acesso de Automação para aquele app. O widget de dólar precisa de internet para buscar uma cotação nova; a última cotação válida continua visível se a rede estiver indisponível. Os valores de orçamento são informativos e lançados manualmente.

### Adicionar uma ROM ao Arcade

1. Abra o widget **Arcade retrô** e selecione **GAME BOY COLOR** ou **SUPER NINTENDO**.
2. Faça um dump legal do cartucho que você possui. Para Game Boy Color, use um arquivo `.gb` ou `.gbc`; para Super Nintendo, use `.sfc` ou `.smc`.
3. Clique em **IMPORTAR ROM** e selecione o arquivo. O PokeDock rejeita arquivos que não pareçam compatíveis com o console escolhido.
4. Depois da confirmação, clique em **JOGAR**. A ROM é copiada para `~/Library/Application Support/PokeDock/ROMs` e não é adicionada ao app, ao repositório ou ao pacote de atualização.

O player usa o [EmulatorJS](https://github.com/EmulatorJS/EmulatorJS), carregado pelo CDN oficial, e precisa de internet ao menos na primeira carga dos arquivos do emulador. A ROM permanece no Mac do usuário.

## Limites do protótipo

O ícone de grama é original deste projeto. Os sprites em pixel art foram importados de [PokeAPI/sprites](https://github.com/PokeAPI/sprites), no caminho sprites/pokemon/{id}.png, em 12 de outubro de 2026, e ficam nos assets locais para uso sem rede. A licença do repositório não substitui autorização para os personagens e imagens Pokémon. A barra temática é uma janela do pokeTab; ela não modifica o Dock do macOS nem reproduz funções como esvaziar a Lixeira e mostrar janelas minimizadas. O equilíbrio de raridade ainda precisa ser ajustado com uso real.
