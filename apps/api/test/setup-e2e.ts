/**
 * Ambiente dos testes e2e. Carregado antes de qualquer import do AppModule.
 * Variaveis ja definidas no processo tem precedencia sobre os arquivos .env.
 */
process.env.NODE_ENV = 'test';
process.env.APP_ENV = process.env.APP_ENV ?? 'DEV';
process.env.LOG_LEVEL = 'silent';
process.env.LOG_PRETTY = 'false';
