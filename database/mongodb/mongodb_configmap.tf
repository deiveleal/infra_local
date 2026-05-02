resource "kubernetes_config_map_v1" "mongodb_init" {
  metadata {
    name      = "mongodb-init-script"
    namespace = var.namespace
  }

  data = {
    # Este script javascript será executado pelo Mongo na inicialização
    "init-test-data.js" = <<-EOT
      // Seleciona ou cria o banco de dados 'banco_teste'
      db = db.getSiblingDB('banco_teste');
      
      // Cria a collection
      db.createCollection('minha_collection_teste');
      
      // (Opcional) Insere alguns dados iniciais
      db.minha_collection_teste.insertMany([
        { nome: "Documento 1", status: "ativo" },
        { nome: "Documento 2", status: "pendente" }
      ]);
      
      print("Inicialização do banco concluída com sucesso!");
    EOT
  }
}