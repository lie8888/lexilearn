// backend/src/controllers/userController.js
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const nodemailer = require('nodemailer');
const { Op } = require('sequelize');
const User = require('../models/User');
const EmailVerification = require('../models/EmailVerification');
const logger = require('../config/logger');
require('dotenv').config();

// 邮件发送器配置 (保持不变)
const transporter = nodemailer.createTransport({
    host: process.env.EMAIL_HOST,
    port: process.env.EMAIL_PORT,
    secure: true, // 使用 SSL/TLS
    auth: { user: process.env.EMAIL_USER, pass: process.env.EMAIL_PASS }
});

// --- 注册/发送验证码 ---
async function register(ctx) {
    const { email } = ctx.request.body;
    logger.info(`[Register Attempt] Email: ${email}`);

    // 基本邮箱格式验证
    if (!email || !/\S+@\S+\.\S+/.test(email)) {
        logger.warn(`[Register Failed] Invalid email format: ${email}`);
        ctx.status = 400;
        ctx.body = { error: '无效的邮箱格式' };
        return;
    }

    try {
        // 查找用户
        let user = await User.findOne({ where: { email } });

        if (user && user.isVerified) {
            // 如果用户已存在且已验证
            logger.warn(`[Register Failed] Email already registered and verified: ${email}`);
            ctx.status = 409; // 409 Conflict is more appropriate than 400
            ctx.body = { error: '该邮箱已被注册' };
            return;
        }

        const code = Math.floor(100000 + Math.random() * 900000).toString();
        const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10分钟有效期

        if (!user) {
            // 如果用户不存在，则创建新用户（未验证状态）
            logger.info(`[Register] Creating new user entry for: ${email}`);
            user = await User.create({ email, passwordHash: '', isVerified: false }); // 密码暂时为空
        } else {
            // 如果用户存在但未验证，重用该用户记录
            logger.info(`[Register] User exists but not verified, reusing entry for: ${email}`);
        }

        // 清除该用户旧的验证码（如果有）
        await EmailVerification.destroy({ where: { userId: user.id } });
        // 创建新的验证码记录
        await EmailVerification.create({ userId: user.id, code, expiresAt });
        logger.info(`[Register] Verification code generated for: ${email}`);

        // 发送邮件
        try {
            await transporter.sendMail({
                from: `"LexiLearn" <${process.env.EMAIL_USER}>`, // 推荐格式
                to: email,
                subject: 'LexiLearn 注册验证码',
                text: `您的 LexiLearn 注册验证码是：${code}，有效期为10分钟。请勿泄露给他人。`
            });
            logger.info(`[Register] Verification email sent successfully to: ${email}`);
            ctx.status = 200;
            ctx.body = { message: '验证码已发送至您的邮箱，请查收。' };
        } catch (emailError) {
            logger.error(`[Register Failed] Failed to send verification email to ${email}: ${emailError.message}`, { stack: emailError.stack });
            // 不把具体邮件错误暴露给前端，但提供通用提示
            ctx.status = 502; // Bad Gateway or 500 Internal Server Error
            ctx.body = { error: '验证码邮件发送失败，请稍后重试或检查邮箱地址是否正确。' };
            // 可选：如果邮件发送失败，是否需要回滚用户创建或验证码记录？取决于业务逻辑
            await EmailVerification.destroy({ where: { userId: user.id, code: code } }); // 清理刚创建的验证码
            // 如果是新创建的用户，可以考虑删除
            // const isNewUser = !existingUser; // 需要在前面判断
            // if (isNewUser) await User.destroy({ where: { id: user.id }});
        }

    } catch (dbError) {
        logger.error(`[Register Failed] Database error during registration for ${email}: ${dbError.message}`, { stack: dbError.stack });
        ctx.status = 500;
        ctx.body = { error: '服务器内部错误，注册请求处理失败。' };
    }
}

// --- 验证邮箱并设置密码 ---
async function verify(ctx) {
    const { email, code, password } = ctx.request.body;
    logger.info(`[Verify Attempt] Email: ${email}, Code: ${code}`);

    // 基本输入验证
    if (!email || !code || !password) {
        logger.warn(`[Verify Failed] Missing fields: email=${email}, code=${code}, password provided=${!!password}`);
        ctx.status = 400;
        ctx.body = { error: '邮箱、验证码和密码不能为空。' };
        return;
    }
    if (password.length < 6) { // 简单密码长度检查
        logger.warn(`[Verify Failed] Password too short for email: ${email}`);
        ctx.status = 400;
        ctx.body = { error: '密码长度不能少于6位。' };
        return;
    }

    try {
        const user = await User.findOne({ where: { email } });

        if (!user) {
            logger.warn(`[Verify Failed] User not found: ${email}`);
            ctx.status = 404; // Not Found
            ctx.body = { error: '用户不存在或邮箱错误' };
            return;
        }

        if (user.isVerified) {
            logger.warn(`[Verify Failed] User already verified: ${email}`);
            ctx.status = 400; // Bad Request
            ctx.body = { error: '该账号已验证，请直接登录。' };
            return;
        }

        const ev = await EmailVerification.findOne({
            where: {
                userId: user.id,
                code: code,
                expiresAt: { [Op.gt]: new Date() } // 检查验证码是否过期
            }
        });

        if (!ev) {
            logger.warn(`[Verify Failed] Invalid or expired code for email: ${email}`);
            ctx.status = 400; // Bad Request
            ctx.body = { error: '验证码错误或已过期' };
            return;
        }

        // 验证成功，哈希密码并更新用户状态
        user.passwordHash = await bcrypt.hash(password, 10); // 使用 await
        user.isVerified = true;
        await user.save();

        // 清除该用户的所有验证码记录
        await EmailVerification.destroy({ where: { userId: user.id } });

        logger.info(`[Verify Success] User verified successfully: ${email}`);
        ctx.status = 200;
        ctx.body = { message: '账号注册并验证成功！' };

    } catch (error) {
        logger.error(`[Verify Failed] Error during verification for ${email}: ${error.message}`, { stack: error.stack });
        ctx.status = 500;
        ctx.body = { error: '服务器内部错误，验证失败。' };
    }
}

// --- 登录 ---
async function login(ctx) {
    const { email, password } = ctx.request.body;
    logger.info(`[Login Attempt] Email: ${email}`);

    // 基本输入验证
    if (!email || !password) {
        logger.warn(`[Login Failed] Missing fields: email=${email}, password provided=${!!password}`);
        ctx.status = 400; // Bad Request
        ctx.body = { error: '邮箱和密码不能为空。' };
        return;
    }

    try {
        const user = await User.findOne({ where: { email } });

        // 检查用户是否存在且已验证
        if (!user || !user.isVerified) {
            logger.warn(`[Login Failed] User not found or not verified: ${email}`);
            // 出于安全考虑，不明确提示是用户不存在还是密码错误，或者未验证
            ctx.status = 401; // Unauthorized
            ctx.body = { error: '邮箱或密码错误，或账号尚未验证。' };
            return;
        }

        // 比较密码哈希
        const match = await bcrypt.compare(password, user.passwordHash);

        if (!match) {
            logger.warn(`[Login Failed] Incorrect password for email: ${email}`);
            ctx.status = 401; // Unauthorized
            ctx.body = { error: '邮箱或密码错误。' }; // 保持和上面一样的模糊提示
            return;
        }

        // 登录成功，生成JWT
        const token = jwt.sign(
            { id: user.id, email: user.email }, // Payload
            process.env.JWT_SECRET,             // Secret Key
            { expiresIn: process.env.JWT_EXPIRES || '1d' } // Expiration (默认1天)
        );

        logger.info(`[Login Success] User logged in successfully: ${email}`);
        ctx.status = 200;
        ctx.body = {
            message: '登录成功',
            token: token,
            user: { id: user.id, email: user.email } // 可以选择性返回一些用户信息
        };

    } catch (error) {
        logger.error(`[Login Failed] Error during login for ${email}: ${error.message}`, { stack: error.stack });
        ctx.status = 500;
        ctx.body = { error: '服务器内部错误，登录失败。' };
    }
}

module.exports = { register, verify, login };