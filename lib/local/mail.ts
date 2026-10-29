import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import nodemailer from 'nodemailer';
import {dataRoot} from './store';
export function privateConfig(){return JSON.parse(readFileSync(/*turbopackIgnore: true*/process.env.CRM_PRIVATE_CONFIG||join(dataRoot(),'privado.json'),'utf8').replace(/^\uFEFF/,''))}
export function mailTransport(config=privateConfig()){if(!config.smtp?.password)throw new Error('Correo sin configurar.');return nodemailer.createTransport({host:config.smtp.host||'mail.gdlinea.com',port:465,secure:true,auth:{user:config.smtp.user,pass:config.smtp.password},connectionTimeout:10000,greetingTimeout:10000,socketTimeout:15000})}
export function publicUrl(){const config=privateConfig();const url=new URL(config.appUrl);if(!['http:','https:'].includes(url.protocol)||url.username||url.password)throw new Error('Dirección del sistema inválida.');return url.origin}
