import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Configuration } from './configuration';

/**
 * Wrapper tipado sobre ConfigService. Evita strings magicas nos modulos.
 */
@Injectable()
export class AppConfigService {
  constructor(private readonly config: ConfigService) {}

  private section<K extends keyof Configuration>(key: K): Configuration[K] {
    return this.config.getOrThrow<Configuration[K]>(key as string);
  }

  get app() {
    return this.section('app');
  }
  get jwt() {
    return this.section('jwt');
  }
  get argon() {
    return this.section('argon');
  }
  get redis() {
    return this.section('redis');
  }
  get storage() {
    return this.section('storage');
  }
  get rateLimit() {
    return this.section('rateLimit');
  }
  get queues() {
    return this.section('queues');
  }
  get push() {
    return this.section('push');
  }
  get log() {
    return this.section('log');
  }

  get isProduction(): boolean {
    return this.app.appEnv === 'PRODUCTION';
  }
  get isDev(): boolean {
    return this.app.appEnv === 'DEV';
  }
}
