# Guia rápido: como mandar seu trabalho (GitHub Desktop)

Você não precisa saber git de linha de comando. O fluxo é sempre o mesmo:
**branch → trabalhar → commit → push → Pull Request**.

## Uma vez só: preparar

1. Instale o [GitHub Desktop](https://desktop.github.com/) e entre com sua conta do GitHub.
2. Peça para ser adicionado como colaborador do repositório `metalworld`.
3. No GitHub Desktop, vá em **File → Clone repository**, escolha `metalworld` e uma pasta no seu PC.
4. Abra o projeto no Godot 4.7 por essa pasta (o arquivo `project.godot`).

## Sempre que for começar uma tarefa

1. **Feche o Godot.** Trocar de branch com ele aberto pode estragar cenas.
2. No GitHub Desktop, em **Current branch**, selecione `main` e clique em **Fetch origin** e depois em **Pull origin**, para pegar a versão mais nova.
3. Clique em **Current branch → New branch**. Dê um nome curto, com a fase na frente:
   - `rua-2/inimigo-motoqueiro`
   - `boss-2/ataque-de-raio`
4. Abra o Godot e trabalhe **só na pasta da sua fase** (`fases/rua_2/`, `fases/boss_2/` etc.).

## Salvar o trabalho (pode fazer várias vezes por dia)

1. No GitHub Desktop aparecem os arquivos alterados. Confira se todos estão dentro da pasta da sua fase. Se apareceu algo fora dela, como `project.godot` ou `jogador.tscn`, clique com o botão direito no arquivo e escolha **Discard changes**, a não ser que tenha combinado antes.
2. Escreva um resumo em português, por exemplo: `Rua 2: inimigo motoqueiro e onda 2 da arena 1`.
3. Clique em **Commit to <sua branch>**.
4. Clique em **Push origin** para mandar para o GitHub.

## Pedir para juntar no jogo (Pull Request)

1. Depois do push, clique em **Create Pull Request** (ou **Branch → Create pull request**). O navegador abre.
2. Preencha o modelo que aparece. Ele tem um checklist curto.
3. Clique em **Create pull request**. O responsável pela base revisa, corrige conflitos e junta.
4. Mande um PR **a cada 2–3 dias**, mesmo com a fase incompleta. PR pequeno = revisão rápida.

## Minha branch ficou velha (a main andou)

1. Feche o Godot.
2. No GitHub Desktop, com a sua branch selecionada: **Branch → Update from main**.
3. Se aparecer **conflito**, não tente resolver sozinho em cena `.tscn`: clique em **Abort merge** e avise no grupo.

## Usando o Codex

O Codex lê o arquivo `AGENTS.md` da raiz e segue as regras do projeto. Bons pedidos:
- "Crie um inimigo novo em fases/rua_2 que corre em zigue-zague e explode perto do jogador."
- "Adicione um ataque ao chefe_2 que dispara 3 anéis seguidos."
- "Rode tests/rodar_testes.sh e corrija o que falhar na minha fase."

Antes de commitar, leia o que ele mudou no GitHub Desktop: só a sua pasta deve aparecer.
