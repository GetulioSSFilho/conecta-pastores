import { Global, Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './strategies/jwt.strategy';
import { PasswordService } from './services/password.service';
import { SessionService } from './services/session.service';
import { TokenService } from './services/token.service';
import { UserPrincipalService } from './services/user-principal.service';

/**
 * Global: UserPrincipalService e SessionService sao usados por modulos de
 * administracao para invalidar acesso imediatamente apos mudanca de permissao.
 */
@Global()
@Module({
  imports: [PassportModule.register({ defaultStrategy: 'jwt' }), JwtModule.register({})],
  controllers: [AuthController],
  providers: [
    AuthService,
    JwtStrategy,
    PasswordService,
    TokenService,
    SessionService,
    UserPrincipalService,
  ],
  exports: [AuthService, PasswordService, SessionService, UserPrincipalService],
})
export class AuthModule {}
