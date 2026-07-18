package com.example.dto;

import com.fasterxml.jackson.annotation.JsonTypeInfo;

// 违规：@JsonTypeInfo 缺 defaultImpl（未知 type id 无兜底；须配 @JsonSubTypes 白名单）
@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, property = "type")
public abstract class Shape {
    public String name;
}
