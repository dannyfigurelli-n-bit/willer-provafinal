drop table if exists historico_partidas;
drop table if exists partidas;
drop table if exists torneios;
drop table if exists jogadores;

create table jogadores (
    id serial primary key,
    nickname varchar(50) not null unique,
    email varchar(100) not null unique,
    senha varchar(100) not null,
    status varchar(20) not null default 'ativo',
    data_cadastro timestamp default current_timestamp,
    constraint chk_status_jogador check (status in ('ativo', 'inativo', 'banido'))
);

create table torneios (
    id serial primary key,
    nome varchar(100) not null,
    modalidade varchar(50) not null,
    data_inicio date not null,
    data_fim date not null,
    status varchar(20) not null default 'agendado',
    constraint chk_status_torneio check (status in ('agendado', 'em_andamento', 'concluido', 'cancelado')),
    constraint chk_datas_torneio check (data_fim >= data_inicio)
);

create table partidas (
    id serial primary key,
    titulo varchar(100) not null,
    torneio_id int not null,
    jogador_id int not null,
    data_partida timestamp not null,
    status varchar(20) not null default 'agendada',
    data_criacao timestamp,
    foreign key (torneio_id) references torneios(id) on delete cascade,
    foreign key (jogador_id) references jogadores(id) on delete restrict,
    constraint chk_status_partida check (status in ('agendada', 'em_andamento', 'concluida', 'cancelada'))
);

create table historico_partidas (
    id serial primary key,
    partida_id int not null,
    acao varchar(30) not null,
    data_registro timestamp default current_timestamp,
    detalhes text,
    foreign key (partida_id) references partidas(id) on delete cascade
);

insert into jogadores (nickname, email, senha, status) values
('kipper', 'kipper@email.com', 'jogos123', 'ativo'),
('joao gabriel', 'joao@email.com', 'campeao2026', 'ativo'),
('ramos', 'ramos@email.com', 'esports2026', 'ativo');

insert into torneios (nome, modalidade, data_inicio, data_fim, status) values
('torneio nacional de gta', 'acao/mundo aberto', '2026-12-01', '2026-12-15', 'agendado'),
('campeonato brasileiro de fifa', 'esportes/futebol', '2027-01-10', '2027-01-25', 'agendado'),
('torneio regional de call of duty', 'acao/tiro', '2026-12-20', '2026-12-22', 'agendado');

insert into partidas (titulo, torneio_id, jogador_id, data_partida, status) values
('kipper vs joao gabriel — fase de grupos', 1, 1, '2026-12-03 15:00:00', 'agendada'),
('joao gabriel vs ramos — quartas de final', 2, 2, '2027-01-12 18:30:00', 'agendada'),
('kipper vs ramos — semifinal', 3, 1, '2026-12-21 14:00:00', 'agendada');

create or replace function fn_buscar_jogadores(termo_busca text)
returns table (
    id int,
    nickname varchar(50),
    email varchar(100),
    status varchar(20)
) as $$
begin
    return query
    select j.id, j.nickname, j.email, j.status
    from jogadores j
    where j.nickname ilike '%' || termo_busca || '%'
       or j.email ilike '%' || termo_busca || '%';
end;
$$ language plpgsql;

create or replace function fn_trigger_validar_partida()
returns trigger as $$
declare
    v_status_jogador varchar(20);
begin
    select status into v_status_jogador
    from jogadores
    where id = new.jogador_id;

    if v_status_jogador is null then
        raise exception 'jogador não encontrado no sistema.';
    end if;

    if v_status_jogador != 'ativo' then
        raise exception 'não é possível cadastrar partida: jogador está %.', v_status_jogador;
    end if;

    new.data_criacao := current_timestamp;

    insert into historico_partidas (partida_id, acao, detalhes)
    values (new.id, 'criação', 'partida cadastrada automaticamente');

    return new;
end;
$$ language plpgsql;

create trigger trg_validar_partida
before insert on partidas
for each row
execute function fn_trigger_validar_partida();

create or replace view vw_painel_principal as
select
    j.nickname,
    p.titulo as partida,
    t.modalidade,
    p.data_partida,
    p.status
from partidas p
inner join jogadores j on p.jogador_id = j.id
inner join torneios t on p.torneio_id = t.id
order by p.data_partida desc;

create or replace view vw_cronograma_partidas as
select
    p.id,
    p.titulo,
    t.nome as torneio,
    p.status,
    p.data_partida,
    (p.data_partida - current_date) as dias_restantes,
    j.nickname as jogador_responsavel
from partidas p
inner join jogadores j on p.jogador_id = j.id
inner join torneios t on p.torneio_id = t.id
order by p.data_partida asc;
