-- Funcionalidades

SELECT e.nome_cientifico, l.descricao, l.coordenadas
FROM especie e
INNER JOIN observacao o ON e.id = o.especie_id
INNER JOIN localizacao l ON o.localizacao_id = l.id;



SELECT h.descricao AS habitat, COUNT(e.id) AS riqueza_especies
FROM habitat h
INNER JOIN especie_habitat eh ON h.id = eh.habitat_id
INNER JOIN especie e ON eh.especie_id = e.id
GROUP BY h.descricao;



SELECT e.nome_cientifico, d.nome
FROM especie e
INNER JOIN especie_doenca ed ON e.id = ed.especie_id
INNER JOIN doenca d ON ed.doenca_id = d.id
WHERE e.nome_cientifico = 'Nome Científico da Espécie';



CREATE OR REPLACE FUNCTION diversidade_especies(area GEOMETRY)
RETURNS INT AS $$
DECLARE
  qtd_especies INT;
BEGIN
  SELECT COUNT(DISTINCT e.id)
  INTO qtd_especies
  FROM especie e
  INNER JOIN observacao o ON e.id = o.especie_id
  INNER JOIN localizacao l ON o.localizacao_id = l.id
  WHERE ST_Within(l.coordenadas, area);
  RETURN qtd_especies;
END;
$$ LANGUAGE plpgsql;




CREATE OR REPLACE FUNCTION calcular_distancia(ponto1 GEOMETRY, ponto2 GEOMETRY)
RETURNS FLOAT AS $$
BEGIN
  RETURN ST_Distance(ponto1, ponto2);
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION atualizar_status_conservacao()
RETURNS TRIGGER AS $$
BEGIN
  IF (SELECT COUNT(*) FROM observacao o WHERE o.especie_id = NEW.especie_id) < 10 THEN
    UPDATE especie SET status_conservacao = 'Em Perigo' WHERE id = NEW.especie_id;
  ELSE
    UPDATE especie SET status_conservacao = 'Segura' WHERE id = NEW.especie_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;



CREATE TRIGGER trigger_atualizar_status
AFTER INSERT OR UPDATE ON observacao
FOR EACH ROW
EXECUTE FUNCTION atualizar_status_conservacao();



CREATE TABLE historico_alteracoes (
  id SERIAL PRIMARY KEY,
  tabela_nome VARCHAR,
  registro_id INT,
  data_hora TIMESTAMP,
  alteracao TEXT
);



CREATE OR REPLACE FUNCTION registrar_historico()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO historico_alteracoes (tabela_nome, registro_id, data_hora, alteracao)
  VALUES (TG_TABLE_NAME, NEW.id, NOW(), 'Registro atualizado');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;



CREATE TRIGGER trigger_registrar_historico
AFTER INSERT OR UPDATE OR DELETE ON especie
FOR EACH ROW
EXECUTE FUNCTION registrar_historico();

CREATE VIEW especies_endemicas AS
SELECT e.nome_cientifico, l.descricao
FROM especie e
INNER JOIN observacao o ON e.id = o.especie_id
INNER JOIN localizacao l ON o.localizacao_id = l.id
WHERE l.descricao = 'Nome do País';



CREATE VIEW riqueza_especies_bioma AS
SELECT h.descricao AS bioma, COUNT(e.id) AS quantidade_especies
FROM habitat h
INNER JOIN especie_habitat eh ON h.id = eh.habitat_id
INNER JOIN especie e ON eh.especie_id = e.id
GROUP BY h.descricao;

CREATE OR REPLACE FUNCTION especies_coexistentes_interacoes(nome_cientifico_invasora VARCHAR)
RETURNS TABLE (
    nome_cientifico_nativa VARCHAR,
    nome_comum VARCHAR,
    descricao TEXT,
    status_conservacao VARCHAR,
    comportamento_migratorio VARCHAR,
    grupo_taxonomico VARCHAR,
    regiao_endemica VARCHAR,
    tipo_interacao VARCHAR,
    descricao_interacao TEXT
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.nome_cientifico AS nome_cientifico_nativa,
        e.nome_comum,
        e.descricao,
        e.status_conservacao,
        e.comportamento_migratorio,
        e.grupo_taxonomico,
        e.regiao_endemica,
        ie.tipo_interacao,
        ie.descricao AS descricao_interacao
    FROM 
        observacoes oi
    INNER JOIN 
        observacoes onativas ON oi.localizacao_id = onativas.localizacao_id
    INNER JOIN 
        especies e ON onativas.especie_id = e.id
    LEFT JOIN
        interacoes_ecologicas ie ON (oi.especie_id = ie.especie_id_1 AND e.id = ie.especie_id_2)
                               OR (oi.especie_id = ie.especie_id_2 AND e.id = ie.especie_id_1)
    WHERE 
        oi.especie_id = (SELECT id FROM especies WHERE nome_cientifico = nome_cientifico_invasora) 
        AND e.id != oi.especie_id;
END;
$$;



CREATE OR REPLACE FUNCTION numero_especies_por_genero(familia_nome VARCHAR)
RETURNS TABLE (
    genero_nome VARCHAR,
    numero_especies INT,
    media_altura FLOAT,
    escalonamento VARCHAR
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT 
        g.nome AS genero_nome,
        COUNT(e.id)::INT AS numero_especies,
        AVG(av.media_altura) AS media_altura,
        CASE
            WHEN AVG(av.media_altura) <= 500 THEN '0 a 500'
            WHEN AVG(av.media_altura) <= 1000 THEN '501 a 1000'
            WHEN AVG(av.media_altura) <= 1500 THEN '1001 a 1500'
            WHEN AVG(av.media_altura) <= 2000 THEN '1501 a 2000'
            WHEN AVG(av.media_altura) <= 2500 THEN '2001 a 2500'
            ELSE 'acima de 2501'
        END::VARCHAR AS escalonamento
    FROM 
        familias f
    INNER JOIN 
        generos g ON f.id = g.familia_id
    INNER JOIN 
        especies e ON g.id = e.genero_id
    INNER JOIN 
        altura_voo av ON e.id = av.especie_id
    WHERE 
        f.nome = familia_nome
    GROUP BY 
        g.nome;
END;
$$;




CREATE OR REPLACE FUNCTION verificar_evolucao_populacional(p_especie_id INT)
RETURNS TABLE (
    populacao_inicio INT, 
    populacao_fim INT, 
    diferenca INT, 
    status TEXT
) LANGUAGE plpgsql AS $$
BEGIN
 
    SELECT populacao_estimada INTO populacao_inicio
    FROM populacao_especies
    WHERE especie_id = p_especie_id AND ano = 2013; -- 10 anos antes de 2023
    

    SELECT populacao_estimada INTO populacao_fim
    FROM populacao_especies
    WHERE especie_id = p_especie_id AND ano = 2023;
    
   
    diferenca := populacao_fim - populacao_inicio;
    
    
    IF diferenca < 0 THEN
        status := 'Estado de Preocupação: Declínio Populacional';
    ELSE
        status := 'População Estável ou em Crescimento';
    END IF;
    
    RETURN NEXT;
END;
$$;






