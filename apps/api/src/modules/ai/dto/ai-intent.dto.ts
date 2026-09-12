import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, MaxLength, MinLength } from 'class-validator';

export class AiIntentDto {
  @ApiProperty({ example: 'Quero ver minha agenda de hoje.' })
  @IsString()
  @MinLength(2)
  @MaxLength(400)
  @IsNotEmpty()
  message!: string;
}
